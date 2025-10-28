import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models.dart';
import 'group_create_screen.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<GroupModel> groups = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final app = context.read<AppState>();
    try {
      final list = await app.api.listGroups();
      setState(() {
        groups = list;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load groups: $e')));
    }
  }

  Future<void> _createGroupFlow() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GroupCreateScreen()),
    );
    await _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Groups"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroups,
            tooltip: "Reload groups",
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _createGroupFlow,
            tooltip: "Create group",
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
              ? const Center(child: Text("No groups found"))
              : ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (_, i) {
                    final g = groups[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: ListTile(
                        title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Members: ${g.memberCount}"),
                        trailing: const Icon(Icons.chat_bubble_outline),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => GroupDetailScreen(group: g)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
