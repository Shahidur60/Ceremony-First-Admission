import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text("Login / Create Account")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Name",
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            if (loading)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                icon: const Icon(Icons.login),
                label: const Text("Continue"),
                onPressed: () async {
                  final name = _nameController.text.trim();
                  final phone = _phoneController.text.trim();

                  if (name.isEmpty || phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter all fields.")),
                    );
                    return;
                  }

                  setState(() => loading = true);
                  try {
                    final existing = await app.api.findUser(name, phone);
                    if (existing != null) {
                      app.me = existing;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Welcome back, ${existing.displayName}!')),
                      );
                    } else {
                      app.me = await app.api.createUser(name, phone);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New user created!')),
                      );
                    }
                    if (mounted) Navigator.pushReplacementNamed(context, '/home');
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  } finally {
                    if (mounted) setState(() => loading = false);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
