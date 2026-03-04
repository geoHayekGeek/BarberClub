import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_bottom_nav.dart';

/// Admin shell: AppBar + body + bottom nav (Points, Valider bon).
class AdminAppShell extends StatelessWidget {
  const AdminAppShell({
    super.key,
    required this.matchedLocation,
    required this.child,
  });

  final String matchedLocation;
  final Widget child;

  bool get _isCompte => matchedLocation.contains('compte');
  /// Points scanner only (from service selection), not offer-scanner tab.
  bool get _isPointsScanner =>
      matchedLocation == '/admin/scanner' || matchedLocation.startsWith('/admin/scanner?');

  int get _adminNavIndex {
    if (matchedLocation.startsWith('/admin/redeem')) return 1;
    if (matchedLocation.startsWith('/admin/offer-scanner')) return 2;
    return 0;
  }

  String get _title {
    if (_isCompte) return 'Compte';
    if (matchedLocation.startsWith('/admin/offer-scanner')) return 'Scanner offres';
    if (matchedLocation.startsWith('/admin/redeem')) return 'Scanner un bon';
    if (_isPointsScanner) return 'Scanner carte fidélité';
    return 'Choisir une prestation';
  }

  bool get _showBottomNav => !_isCompte && !_isPointsScanner;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _isCompte || _isPointsScanner
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/admin'),
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
