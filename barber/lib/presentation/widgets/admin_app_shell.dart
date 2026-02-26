import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Admin-only shell: AppBar + body. No bottom nav, no drawer.
/// Scanner: title "Scanner carte fidélité", action = profile → Compte.
/// Compte: back → Scanner, title "Compte".
class AdminAppShell extends StatelessWidget {
  const AdminAppShell({
    super.key,
    required this.matchedLocation,
    required this.child,
  });

  final String matchedLocation;
  final Widget child;

  bool get _isCompte => matchedLocation.contains('compte');
  bool get _isAdminRoot => matchedLocation == '/admin' || matchedLocation == '/admin/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _isCompte
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/admin'),
              )
            : null,
        title: Text(
          _isCompte ? 'Compte' : (_isAdminRoot ? 'Choisir une prestation' : 'Scanner carte fidélité'),
        ),
        actions: _isCompte
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  onPressed: () => context.go('/admin/compte'),
                ),
              ],
      ),
      body: child,
    );
  }
}
