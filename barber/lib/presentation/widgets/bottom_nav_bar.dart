import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Solid black bottom navigation bar.
/// Center item (RDV, index 2) is elevated slightly above the bar using a Stack.
/// Tab order matches StatefulShellBranch indexes in app_router.dart:
/// 0: Accueil, 1: Coiffeurs, 2: RDV (center), 3: Carte, 4: Offres
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key, this.navigationShell});
  final StatefulNavigationShell? navigationShell;

  static const int _centerIndex = 2;

  static const _tabs = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'ACCUEIL', path: '/home'),
    _NavItem(icon: Icons.content_cut_outlined, activeIcon: Icons.content_cut, label: 'COIFFEURS', path: '/coiffeurs'),
    _NavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'RDV', path: '/rdv'),
    _NavItem(icon: Icons.card_giftcard_outlined, activeIcon: Icons.card_giftcard, label: 'CARTE', path: '/carte-fidelite'),
    _NavItem(icon: Icons.local_offer_outlined, activeIcon: Icons.local_offer, label: 'OFFRES', path: '/offres'),
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
    if (base == '/home' && path.startsWith('/home')) return true;
    if (base == '/coiffeurs' && path.startsWith('/coiffeurs')) return true;
    if (base == '/rdv' && path.startsWith('/rdv')) return true;
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

    return Container(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Row of all tab items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_tabs.length, (index) {
                  if (index == _centerIndex) {
                    // Empty space for center — the circle floats above via Positioned
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _onTabTapped(context, index),
                        child: _buildCenterLabel(
                          _tabs[index].label,
                          index == currentIndex,
                        ),
                      ),
                    );
                  }
                  return Expanded(
                    child: _buildRegularItem(
                      context,
                      _tabs[index],
                      index == currentIndex,
                      index,
                    ),
                  );
                }),
              ),
              // RDV circle — elevated above bar
              Positioned(
                top: -18,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => _onTabTapped(context, _centerIndex),
                    child: AnimatedScale(
                      scale: currentIndex == _centerIndex ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.12),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegularItem(BuildContext context, _NavItem item, bool isActive, int index) {
    return GestureDetector(
      onTap: () => _onTabTapped(context, index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: isActive ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isActive ? item.activeIcon : item.icon,
              size: 22,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0.8,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.55),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCenterLabel(String label, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: isActive ? Colors.white : Colors.white.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
}
