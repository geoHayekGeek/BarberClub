import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
      iconAsset: 'assets/icons/nav_barbers.svg',
      label: 'BARBERS',
    ),
    _DockItem(
      branchIndex: 3,
      path: '/carte-fidelite',
      iconAsset: 'assets/icons/nav_carte_fidelite.svg',
      label: 'CARTE FIDÉLITÉ',
    ),
    _DockItem(
      branchIndex: 2,
      path: '/rdv',
      iconAsset: 'assets/icons/nav_reserver_small.svg',
      label: 'RÉSERVER',
      isCenter: true,
    ),
    _DockItem(
      branchIndex: 4,
      path: '/offres',
      iconAsset: 'assets/icons/nav_offres.svg',
      label: 'OFFRES',
    ),
    _DockItem(
      branchIndex: 0,
      path: '/home',
      iconAsset: 'assets/icons/nav_salon.svg',
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
    if (path == '/carte-fidelite' || path.startsWith('/carte-fidelite')) {
      return 3;
    }
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
        padding: EdgeInsets.fromLTRB(12, 8, 12, dockBottomPadding),
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
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xF20A0A0A),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0x1AFFFFFF),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x80000000),
                            blurRadius: 32,
                            offset: Offset(0, 8),
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
  const _SideDockItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _DockItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : Colors.white.withValues(alpha: 0.4);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                item.iconAsset,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                textScaler: const TextScaler.linear(1),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  height: 1,
                  letterSpacing: 0.35,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
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
  const _CenterReserveItem({required this.item, required this.onTap});

  final _DockItem item;
  final VoidCallback onTap;

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
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4DFFFFFF),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: SvgPicture.asset(
                  item.iconAsset,
                  width: 10,
                  height: 10,
                  fit: BoxFit.contain,
                  colorFilter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              textScaler: const TextScaler.linear(1),
              style: const TextStyle(
                fontSize: 9,
                height: 1,
                letterSpacing: 0.35,
                fontWeight: FontWeight.w600,
                color: Colors.white,
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
    required this.iconAsset,
    required this.label,
    this.isCenter = false,
  });

  final int branchIndex;
  final String path;
  final String iconAsset;
  final String label;
  final bool isCenter;
}
