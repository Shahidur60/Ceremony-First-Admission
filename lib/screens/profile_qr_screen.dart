import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models.dart';

class ProfileQrScreen extends StatelessWidget{
  final UserProfile user;
  const ProfileQrScreen({super.key, required this.user});
  @override
  Widget build(BuildContext context){
    final payload = {
      "userId": user.userId,
      "displayName": user.displayName,
      "fingerprint": user.fingerprint
    };
    final qrData = payload.toString();
    return Scaffold(
      appBar: AppBar(title: const Text("Your Contact QR")),
      body: Center(
        child: Card(
          elevation: 2,
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(user.displayName, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height:12),
              QrImageView(data: qrData, size: 240),
              const SizedBox(height:8),
              Text("Fingerprint: ${user.fingerprint.substring(0,12)}…"),
              const SizedBox(height:4),
              const Text("Ask others to scan this to verify & link you."),
            ]),
          ),
        ),
      ),
    );
  }
}
