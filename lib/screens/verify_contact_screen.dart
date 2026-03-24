import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models.dart';

class VerifyContactScreen extends StatefulWidget {
  final UserProfile me;
  final UserProfile peer;

  const VerifyContactScreen({
    super.key,
    required this.me,
    required this.peer,
  });

  @override
  State<VerifyContactScreen> createState() => _VerifyContactScreenState();
}

class _VerifyContactScreenState extends State<VerifyContactScreen> {
  bool verified = false;
  String? status;
  late String sas;

  @override
  void initState() {
    super.initState();
    sas = _computeSas(widget.me.userId, widget.peer.userId);
  }

  String _computeSas(String a, String b) {
    final pair = [a, b]..sort();
    final input = utf8.encode('${pair[0]}:${pair[1]}');
    final digest = sha256.convert(input).toString();
    final digits = digest.replaceAll(RegExp(r'[^0-9]'), '');
    final six = (digits.length >= 6
        ? digits.substring(0, 6)
        : digits.padRight(6, '0'));
    return six;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text("Verify Contact")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(widget.peer.displayName),
                subtitle: Text(
                  "fp: ${widget.peer.fingerprint.substring(0, 12)}… • ${widget.peer.phone}",
                ),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              status ?? "Select a verification method:",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),

            if (!verified)
              FilledButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Scan Contact QR"),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _ScanPage()),
                  );

                  if (result is Map &&
                      result['userId'] == widget.peer.userId) {
                    final contactList =
                        await app.api.listContacts(widget.me.userId);
                    final contact = contactList.firstWhere(
                      (c) => c.phone == widget.peer.phone,
                      orElse: () => throw Exception("contact_not_found"),
                    );

                    await app.api.linkVerifyContact(
                      ownerId: widget.me.userId,
                      contactId: contact.contactId,
                      linkedUserId: widget.peer.userId,
                      attestation: "qr verified",
                    );

                    setState(() {
                      verified = true;
                      status = "Verified ✓ via QR";
                    });
                  } else {
                    setState(() {
                      status =
                          "QR mismatch. Make sure you scanned the right contact.";
                    });
                  }
                },
              ),

            const SizedBox(height: 12),

            if (!verified)
              FilledButton.icon(
                icon: const Icon(Icons.password),
                label: const Text("Compare 6-digit SAS"),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("SAS Verification"),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Your SAS: $sas",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Ask your peer to read their SAS aloud and compare. "
                            "They should match exactly.",
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: "Enter peer’s SAS",
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            onSubmitted: (entered) async {
                              if (entered == sas) {
                                final contactList =
                                    await app.api.listContacts(widget.me.userId);
                                final contact = contactList.firstWhere(
                                  (c) => c.phone == widget.peer.phone,
                                  orElse: () =>
                                      throw Exception("contact_not_found"),
                                );

                                await app.api.linkVerifyContact(
                                  ownerId: widget.me.userId,
                                  contactId: contact.contactId,
                                  linkedUserId: widget.peer.userId,
                                  attestation: "sas verified",
                                );

                                if (mounted) {
                                  Navigator.pop(context);
                                  setState(() {
                                    verified = true;
                                    status = "Verified ✓ via SAS";
                                  });
                                }
                              } else {
                                if (mounted) {
                                  Navigator.pop(context);
                                  setState(() {
                                    status =
                                        "SAS mismatch. Try again or use QR scan.";
                                  });
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const Spacer(),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: verified ? () => Navigator.pop(context, true) : null,
                    child: const Text("Done"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage({super.key});
  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool got = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Contact QR")),
      body: MobileScanner(
        onDetect: (capture) {
          if (got) return;
          got = true;
          final barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final raw = barcodes.first.rawValue ?? "";
            try {
              final parsed = jsonDecode(raw);
              if (parsed is Map<String, dynamic>) {
                Navigator.pop(context, parsed);
              } else {
                Navigator.pop(context, null);
              }
            } catch (_) {
              Navigator.pop(context, null);
            }
          }
        },
      ),
    );
  }
}
