import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models.dart';
import 'verify_contact_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  bool loading = true;
  List<ContactEntry> contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    try {
      final list = await app.api.listContacts(app.me!.userId);
      setState(() {
        contacts = list;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading contacts: $e')),
      );
    }
  }

  Future<void> _addContact() async {
    final app = context.read<AppState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Contact"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Phone")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final newC = await app.api.addContact(
                  app.me!.userId,
                  nameCtrl.text.trim(),
                  phoneCtrl.text.trim(),
                );
                setState(() => contacts.add(newC));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Contact added: ${newC.name}")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyContact(ContactEntry c) async {
    final app = context.read<AppState>();

    // Try to match this contact to a registered user
    final allUsers = await app.api.listUsers();
    final peer = allUsers.firstWhere(
      (u) => u.phone == c.phone,
      orElse: () => UserProfile(
        userId: 'none',
        displayName: c.name,
        phone: c.phone,
        identityKeyHex: 'UNKNOWN',
        fingerprint: 'UNKNOWN',
      ),
    );

    if (peer.userId == 'none') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This contact isn't registered yet.")),
      );
      return;
    }

    final verified = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerifyContactScreen(me: app.me!, peer: peer),
      ),
    );

    if (verified == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Contacts")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : contacts.isEmpty
              ? const Center(child: Text("No contacts yet."))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: const [
                          Icon(Icons.verified, color: Colors.green, size: 18),
                          SizedBox(width: 4),
                          Text("Verified  "),
                          Icon(Icons.hourglass_empty, color: Colors.orange, size: 18),
                          SizedBox(width: 4),
                          Text("Unverified  "),
                          Icon(Icons.warning_amber, color: Colors.amber, size: 18),
                          SizedBox(width: 4),
                          Text("Needs reverify"),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (_, i) {
                          final c = contacts[i];
                          final icon = c.verified
                              ? const Icon(Icons.verified, color: Colors.green)
                              : (c.state == 'needs_reverify'
                                  ? const Icon(Icons.warning_amber, color: Colors.amber)
                                  : const Icon(Icons.hourglass_empty, color: Colors.orange));

                          return ListTile(
                            leading: icon,
                            title: Text(c.name),
                            subtitle: Text("${c.phone} • ${c.state}"),
                            onTap: () async {
                              if (c.state == 'unverified' || c.state == 'needs_reverify') {
                                await _verifyContact(c);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("${c.name} is already verified.")),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        child: const Icon(Icons.add),
      ),
    );
  }
}
