import 'dart:math';

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
  late String localSas;
  late String peerSas; // simulated for demo

  @override
  void initState() {
    super.initState();
    // Generate a 6-digit SAS for local verification (simulated)
    localSas = _generateSas();
    peerSas = _generateSas(); // In real life this would come from peer
  }

  String _generateSas() {
    final r = Random();
    return List.generate(6, (_) => r.nextInt(10)).join();
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
            // --- Contact info ---
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(widget.peer.displayName),
                subtitle: Text(
                    "fp: ${widget.peer.fingerprint.substring(0, 12)}… • ${widget.peer.phone}"),
              ),
            ),
            const SizedBox(height: 12),

            // --- Status text ---
            Text(
              status ?? "Select a verification method:",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),

            // --- QR Scan Verification ---
            if (!verified)
              FilledButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Scan Contact QR"),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _ScanPage()),
                  );

                  if (result is Map && result['userId'] == widget.peer.userId) {
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
                    setState(() => status =
                        "QR mismatch. Make sure you scanned the right contact.");
                  }
                },
              ),

            const SizedBox(height: 12),

            // --- SAS (6-digit) Verification ---
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
                            "Your SAS: $localSas",
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                              "Ask your peer to read their SAS aloud and compare. "
                              "They should match exactly."),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: "Enter peer’s SAS",
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            onSubmitted: (entered) async {
                              if (entered == localSas) {
                                final contactList = await app.api
                                    .listContacts(widget.me.userId);
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
                                  setState(() => status =
                                      "SAS mismatch. Try again or use QR scan.");
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel")),
                      ],
                    ),
                  );
                },
              ),

            const Spacer(),

            // --- Close / Done ---
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
                    onPressed:
                        verified ? () => Navigator.pop(context, true) : null,
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

// QR scanning sub-page
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
              final parsed = _parseMap(raw);
              Navigator.pop(context, parsed);
            } catch (_) {
              Navigator.pop(context, null);
            }
          }
        },
      ),
    );
  }

  Map<String, String> _parseMap(String s) {
    if (!s.startsWith("{") || !s.endsWith("}")) return {};
    final inner = s.substring(1, s.length - 1);
    final parts = inner.split(", ");
    final map = <String, String>{};
    for (final p in parts) {
      final i = p.indexOf(": ");
      if (i > 0) {
        final key = p.substring(0, i);
        final val = p.substring(i + 2);
        map[key] = val;
      }
    }
    return map;
  }
}
