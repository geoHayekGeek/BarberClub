import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared bottom navigation bar for main screens.
/// Uses [navigationShell] when inside [StatefulShellRoute] (preserves tab state).
/// When [navigationShell] is null, uses [context.go] for tab switches (e.g. on Compte page).
class BottomNavBar extends StatelessWidget {
  final StatefulNavigationShell? navigationShell;

  const BottomNavBar({super.key, this.navigationShell});

  static const _tabs = [
    (_NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Accueil', path: '/home')),
    (_NavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'RDV', path: '/rdv')),
    (_NavItem(icon: Icons.content_cut_outlined, activeIcon: Icons.content_cut, label: 'Nos coiffeurs', path: '/coiffeurs')),
    (_NavItem(icon: Icons.store_outlined, activeIcon: Icons.store, label: 'Nos salons', path: '/salons')),
    (_NavItem(icon: Icons.card_giftcard_outlined, activeIcon: Icons.card_giftcard, label: 'Carte fidélité', path: '/carte-fidelite')),
    (_NavItem(icon: Icons.local_offer_outlined, activeIcon: Icons.local_offer, label: 'Offres', path: '/offres')),
  ];

  int _getCurrentIndex(BuildContext context) {
    if (navigationShell != null) {
      return navigationShell!.currentIndex;
    }
    final path = GoRouterState.of(context).uri.path;
    final idx = _tabs.indexWhere((t) => _pathMatches(path, t.path));
    return idx >= 0 ? idx : 0;
  }

  bool _pathMatches(String path, String tabPath) {
    final base = tabPath.split('?').first;
    if (path == base) return true;
    if (base == '/salons' && path.startsWith('/salons')) return true;
    if (base == '/coiffeurs' && path.startsWith('/coiffeurs')) return true;
    if (base == '/offres' && (path == '/offres' || path.startsWith('/offres/'))) return true;
    return false;
  }

  void _onTabTapped(BuildContext context, int index) {
    if (navigationShell != null) {
      navigationShell!.goBranch(index);
      return;
    }
    context.go(_tabs[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);
    final selectedColor = Theme.of(context).colorScheme.secondary;
    final unselectedColor = Colors.white.withOpacity(0.6);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Accueil, RDV, Nos coiffeurs
              Row(
                children: [0, 1, 2].map((i) => _buildNavItem(context, i, currentIndex, selectedColor, unselectedColor)).toList(),
              ),
              const SizedBox(height: 4),
              // Row 2: Nos salons, Carte fidélité, Offres
              Row(
                children: [3, 4, 5].map((i) => _buildNavItem(context, i, currentIndex, selectedColor, unselectedColor)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    int currentIndex,
    Color selectedColor,
    Color unselectedColor,
  ) {
    final t = _tabs[index];
    final isSelected = index == currentIndex;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTabTapped(context, index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? t.activeIcon : t.icon,
                  size: 24,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
                const SizedBox(height: 4),
                Text(
                  t.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? selectedColor : unselectedColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.path});
}
