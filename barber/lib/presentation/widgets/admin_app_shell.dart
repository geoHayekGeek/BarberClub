import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_bottom_nav.dart';

/// Admin shell: AppBar + body + bottom nav (Gagner des points, Valider une récompense, Paramètres).
class AdminAppShell extends StatelessWidget {
  const AdminAppShell({
    super.key,
    required this.matchedLocation,
    required this.child,
  });

  final String matchedLocation;
  final Widget child;

  bool get _isCompte => matchedLocation.contains('compte');
  bool get _isScanner => matchedLocation.contains('scanner');

  int get _adminNavIndex {
    if (matchedLocation.startsWith('/admin/redeem')) return 1;
    if (matchedLocation.startsWith('/admin/settings')) return 2;
    return 0;
  }

  String get _title {
    if (_isCompte) return 'Compte';
    if (_isScanner) return 'Scanner carte fidélité';
    if (matchedLocation.startsWith('/admin/redeem')) return 'Scanner un bon';
    if (matchedLocation.startsWith('/admin/settings')) return 'Paramètres';
    return 'Choisir une prestation';
  }

  bool get _showBottomNav => !_isCompte && !_isScanner;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _isCompte || _isScanner
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_isScanner) context.go('/admin');
                  else context.go('/admin');
                },
              )
            : null,
        title: Text(_title),
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
      bottomNavigationBar: _showBottomNav ? AdminBottomNav(currentIndex: _adminNavIndex) : null,
    );
  }
}
