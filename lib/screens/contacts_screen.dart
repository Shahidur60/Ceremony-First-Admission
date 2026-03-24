import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
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
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: "Phone"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // Import from OS address book
  Future<void> _importFromPhone() async {
    final app = context.read<AppState>();

    final granted = await FlutterContacts.requestPermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contacts permission denied.")),
      );
      return;
    }

    final deviceContacts = await FlutterContacts.getContacts(
      withProperties: true,
    );
    if (deviceContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No contacts found in address book.")),
      );
      return;
    }

    Contact? picked;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Import from address book"),
        content: SizedBox(
          width: 360,
          height: 400,
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return ListView.builder(
                itemCount: deviceContacts.length,
                itemBuilder: (_, i) {
                  final c = deviceContacts[i];
                  final displayName = c.displayName.isNotEmpty
                      ? c.displayName
                      : (c.name.first + ' ' + c.name.last);
                  final phone =
                      c.phones.isNotEmpty ? c.phones.first.number : '';
                  return RadioListTile<Contact>(
                    value: c,
                    groupValue: picked,
                    title: Text(displayName),
                    subtitle: Text(phone),
                    onChanged: (val) {
                      setStateDialog(() => picked = val);
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, picked),
            child: const Text("Import"),
          ),
        ],
      ),
    ).then((v) => picked = v);

    if (picked == null) return;

    final displayName = picked!.displayName.isNotEmpty
        ? picked!.displayName
        : (picked!.name.first + ' ' + picked!.name.last);
    final phone =
        picked!.phones.isNotEmpty ? picked!.phones.first.number : '';

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selected contact has no phone number.")),
      );
      return;
    }

    try {
      final newC =
          await app.api.addContact(app.me!.userId, displayName, phone);
      setState(() => contacts.add(newC));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Imported contact: ${newC.name}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error importing contact: $e")),
      );
    }
  }

  Future<void> _verifyContact(ContactEntry c) async {
    final app = context.read<AppState>();

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
      appBar: AppBar(
        title: const Text("Contacts"),
        actions: [
          IconButton(
            icon: const Icon(Icons.import_contacts),
            tooltip: "Import from phone",
            onPressed: _importFromPhone,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : contacts.isEmpty
              ? const Center(child: Text("No contacts yet."))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        children: const [
                          Icon(Icons.verified, color: Colors.green, size: 18),
                          SizedBox(width: 4),
                          Text("Verified  "),
                          Icon(Icons.hourglass_empty,
                              color: Colors.orange, size: 18),
                          SizedBox(width: 4),
                          Text("Unverified  "),
                          Icon(Icons.warning_amber,
                              color: Colors.amber, size: 18),
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
                                  ? const Icon(Icons.warning_amber,
                                      color: Colors.amber)
                                  : const Icon(Icons.hourglass_empty,
                                      color: Colors.orange));

                          return ListTile(
                            leading: icon,
                            title: Text(c.name),
                            subtitle: Text("${c.phone} • ${c.state}"),
                            onTap: () async {
                              if (c.state == 'unverified' ||
                                  c.state == 'needs_reverify') {
                                await _verifyContact(c);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text("${c.name} is already verified."),
                                  ),
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
