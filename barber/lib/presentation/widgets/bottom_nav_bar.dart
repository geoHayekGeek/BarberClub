import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Website-style bottom dock:
/// left 2 tabs + center elevated reserve button + right 2 tabs.
class BottomNavBar extends ConsumerWidget {
  const BottomNavBar({super.key, this.navigationShell});

  final StatefulNavigationShell? navigationShell;

  static const _items = [
    _DockItem(
      branchIndex: 1,
      path: '/coiffeurs',
      icon: Icons.groups_2_outlined,
      activeIcon: Icons.groups_2,
      label: 'BARBERS',
    ),
    _DockItem(
      branchIndex: 3,
      path: '/carte-fidelite',
      icon: Icons.sell_outlined,
      activeIcon: Icons.sell,
      label: 'TARIFS',
    ),
    _DockItem(
      branchIndex: 2,
      path: '/rdv',
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      label: 'RÉSERVER',
      isCenter: true,
    ),
    _DockItem(
      branchIndex: 4,
      path: '/offres',
      icon: Icons.percent,
      activeIcon: Icons.percent,
      label: 'OFFRES',
    ),
    _DockItem(
      branchIndex: 0,
      path: '/home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'SALON',
    ),
  ];

  int _getCurrentBranchIndex(BuildContext context) {
    if (navigationShell != null) {
      return navigationShell!.currentIndex;
    }

    final path = GoRouterState.of(context).uri.path;
    if (path == '/home' || path.startsWith('/home')) return 0;
    if (path == '/coiffeurs' || path.startsWith('/coiffeurs')) return 1;
    if (path == '/rdv' || path.startsWith('/rdv')) return 2;
    if (path == '/carte-fidelite' || path.startsWith('/carte-fidelite'))
      return 3;
    if (path == '/offres' || path.startsWith('/offres/')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, _DockItem item) {
    if (navigationShell != null) {
      navigationShell!.goBranch(item.branchIndex);
      return;
    }

    context.go(item.path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBranch = _getCurrentBranchIndex(context);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final dockBottomPadding = bottomInset > 0 ? bottomInset + 6 : 12.0;

    final leftItems = [_items[0], _items[1]];
    final centerItem = _items[2];
    final rightItems = [_items[3], _items[4]];

    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 8, 14, dockBottomPadding),
        child: SizedBox(
          height: 86,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE6050505),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF2A2A2A),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x99000000),
                            blurRadius: 22,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ...leftItems.map(
                            (item) => Expanded(
                              child: _SideDockItem(
                                item: item,
                                isActive: currentBranch == item.branchIndex,
                                onTap: () => _onTap(context, item),
                              ),
                            ),
                          ),
                          const SizedBox(width: 84),
                          ...rightItems.map(
                            (item) => Expanded(
                              child: _SideDockItem(
                                item: item,
                                isActive: currentBranch == item.branchIndex,
                                onTap: () => _onTap(context, item),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: _CenterReserveItem(
                  item: centerItem,
                  isActive: currentBranch == centerItem.branchIndex,
                  onTap: () => _onTap(context, centerItem),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideDockItem extends StatelessWidget {
  final _DockItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _SideDockItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : Colors.white.withOpacity(0.58);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? item.activeIcon : item.icon,
                size: 18,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.6,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterReserveItem extends StatelessWidget {
  final _DockItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _CenterReserveItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(isActive ? 0.28 : 0.18),
                    blurRadius: isActive ? 22 : 16,
                    spreadRadius: 0.8,
                  ),
                ],
              ),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                size: 20,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
                color: Colors.white.withOpacity(isActive ? 0.98 : 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockItem {
  const _DockItem({
    required this.branchIndex,
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isCenter = false,
  });

  final int branchIndex;
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isCenter;
}
