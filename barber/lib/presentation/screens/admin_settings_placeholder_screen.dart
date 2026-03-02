import 'package:flutter/material.dart';

/// Admin settings placeholder (Section 6).
class AdminSettingsPlaceholderScreen extends StatelessWidget {
  const AdminSettingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Paramètres',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white70),
      ),
    );
  }
}
