import 'package:flutter/material.dart';

/// RDV (Appointments) screen placeholder
class RdvScreen extends StatelessWidget {
  const RdvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RDV'),
      ),
      body: SafeArea(
        child: Center(
          child: Text(
            'RDV',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
    );
  }
}
