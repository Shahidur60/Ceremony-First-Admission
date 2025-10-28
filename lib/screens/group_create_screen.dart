import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});
  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final name = TextEditingController(text: "Research WG");
  final t = TextEditingController(text: "1");

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text("Create Group")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: "Group name")),
          TextField(controller: t, decoration: const InputDecoration(labelText: "Endorsements needed (t)"), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final g = await app.api.createGroup(
                name: name.text.trim(),
                creatorUserId: app.me!.userId,
                admins: [app.me!.userId],
                endorsementsNeeded: int.tryParse(t.text.trim()) ?? 1,
              );
              if (!mounted) return;
              Navigator.pop(context, g);
            },
            child: const Text("Create"),
          )
        ]),
      ),
    );
  }
}
