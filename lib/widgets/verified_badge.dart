import 'package:flutter/material.dart';

class VerifiedBadge extends StatelessWidget {
  final bool verified;
  const VerifiedBadge({super.key, required this.verified});

  @override
  Widget build(BuildContext context) {
    return Icon(
      verified ? Icons.verified : Icons.verified_outlined,
      color: verified ? Colors.green : Colors.grey,
      size: 16,
    );
  }
}
