import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Menu item data class
class MenuItem {
  final IconData icon;
  final String label;
  final String route;
  final bool isCurrentPage;

  const MenuItem({
    required this.icon,
    required this.label,
    required this.route,
    this.isCurrentPage = false,
  });
}

/// Bottom sheet menu for Home screen
class HomeMenuBottomSheet extends StatelessWidget {
  final String currentRoute;

  const HomeMenuBottomSheet({
    super.key,
    required this.currentRoute,
  });

  static const List<MenuItem> _menuItems = [
    MenuItem(
      icon: Icons.home_outlined,
      label: 'Accueil',
      route: '/home',
    ),
    MenuItem(
      icon: Icons.calendar_today_outlined,
      label: 'RDV',
      route: '/rdv',
    ),
    MenuItem(
      icon: Icons.content_cut_outlined,
      label: 'Nos coiffeurs',
      route: '/coiffeurs',
    ),
    MenuItem(
      icon: Icons.store_outlined,
      label: 'Nos salons',
      route: '/salons',
    ),
    MenuItem(
      icon: Icons.card_giftcard_outlined,
      label: 'Carte fidélité',
      route: '/carte-fidelite',
    ),
    MenuItem(
      icon: Icons.local_offer_outlined,
      label: 'Offres',
      route: '/offres',
    ),
    MenuItem(
      icon: Icons.person_outline,
      label: 'Compte',
      route: '/compte',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrentPage = (item) => item.route == currentRoute;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Menu items
            ..._menuItems.map((item) {
              final isCurrent = isCurrentPage(item);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(item.route);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Colors.white.withOpacity(0.05)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          color: Colors.white.withOpacity(isCurrent ? 1.0 : 0.8),
                          size: 24,
                        ),
                        const SizedBox(width: 20),
                        Text(
                          item.label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white.withOpacity(isCurrent ? 1.0 : 0.8),
                            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (isCurrent) ...[
                          const Spacer(),
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Show the menu bottom sheet
  static void show(BuildContext context, String currentRoute) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => HomeMenuBottomSheet(currentRoute: currentRoute),
    );
  }
}
