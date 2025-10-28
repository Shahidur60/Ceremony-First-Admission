import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models.dart';

class GroupDetailScreen extends StatefulWidget {
  final GroupModel group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late GroupModel group;
  bool loading = true;
  List<ChatMessage> messages = [];
  final _textCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    group = widget.group;
    _reloadAll();
  }

  Future<void> _reloadAll() async {
    final app = context.read<AppState>();
    try {
      final g = await app.api.getGroup(group.groupId);
      final ms = await app.api.listMessages(group.groupId, app.me!.userId);
      setState(() {
        group = g;
        messages = ms;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _sendMessage() async {
    final app = context.read<AppState>();
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    try {
      await app.api.sendMessage(group.groupId, app.me!.userId, text);
      await _reloadAll();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
    }
  }

  Future<void> _addMember() async {
    final app = context.read<AppState>();
    final verified = await app.api.listVerifiedOnly(app.me!.userId);
    if (verified.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No verified contacts. Verify a contact first in Contacts tab.')),
      );
      return;
    }

    ContactEntry? pick;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add member (Verified only)"),
        content: SizedBox(
          width: 360,
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return ListView.builder(
                shrinkWrap: true,
                itemCount: verified.length,
                itemBuilder: (_, i) {
                  final c = verified[i];
                  return RadioListTile<ContactEntry>(
                    value: c,
                    groupValue: pick,
                    onChanged: (v) => setStateDialog(() => pick = v),
                    title: Text(c.name),
                    subtitle: Text(c.phone),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, pick), child: const Text("Add")),
        ],
      ),
    ).then((v) => pick = v);

    if (pick == null) return;

    try {
      await app.api.inviteToGroup(group.groupId, app.me!.userId, pick!.linkedUserId!);
      await _reloadAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invited ${pick!.name}. ${group.endorsementsNeeded ?? 1} endorsement(s) may be required.")),
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('verify_first')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This contact isn’t verified. Go to Contacts and complete verification.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invite failed: $e")));
      }
    }
  }

  Future<void> _endorse(String joiningUserId) async {
    final app = context.read<AppState>();
    try {
      await app.api.endorse(group.groupId, app.me!.userId, joiningUserId);
      await _reloadAll();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Endorse failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AppState>().me!;
    final pending = group.members.where((m) => !m.verified).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add member (verified only)',
            onPressed: _addMember,
          )
        ],
      ),
      body: Column(
        children: [
          if ((group.endorsementsNeeded ?? 1) > 1)
            Container(
              width: double.infinity,
              color: Colors.amber.withOpacity(.2),
              padding: const EdgeInsets.all(8),
              child: Text("This group requires ${group.endorsementsNeeded} endorsements for new members."),
            ),

          if (pending.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.orange.withOpacity(.15),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Pending members:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...pending.map((p) {
                    final have = group.endorsements.where((e) => e.endorsed == p.userId).length;
                    final need = group.endorsementsNeeded ?? 1;
                    final canEndorse = group.members.any((m) => m.userId == me.userId);

                    return Row(
                      children: [
                        Expanded(child: Text("• ${p.userId}  ($have/$need)")),
                        if (canEndorse)
                          TextButton(
                            onPressed: () => _endorse(p.userId),
                            child: const Text("Endorse"),
                          ),
                      ],
                    );
                  }).toList()
                ],
              ),
            ),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(child: Text("No messages yet"))
                    : ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final m = messages[i];
                          final isMine = m.senderUserId == me.userId;
                          final isSystem = m.isSystem;
                          return Align(
                            alignment: isSystem ? Alignment.center : (isMine ? Alignment.centerRight : Alignment.centerLeft),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSystem ? Colors.grey[300] : (isMine ? Colors.blue[200] : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(isSystem ? m.text : "${m.senderName}: ${m.text}"),
                            ),
                          );
                        },
                      ),
          ),

          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: const InputDecoration(
                      hintText: "Type message...",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
