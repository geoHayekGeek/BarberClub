import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Admin bottom nav: Gagner des points, Valider une récompense, Paramètres.
class AdminBottomNav extends StatelessWidget {
  const AdminBottomNav({
    super.key,
    required this.currentIndex,
  });

  final int currentIndex;

  static const _tabs = [
    _AdminNavItem(icon: Icons.add_circle_outline, label: 'Gagner des points', path: '/admin'),
    _AdminNavItem(icon: Icons.qr_code_scanner, label: 'Valider une récompense', path: '/admin/redeem'),
    _AdminNavItem(icon: Icons.settings_outlined, label: 'Paramètres', path: '/admin/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_tabs.length, (index) {
              final item = _tabs[index];
              final selected = index == currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => context.go(item.path),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        color: selected ? Colors.white : Colors.white54,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white54,
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _AdminNavItem {
  final IconData icon;
  final String label;
  final String path;

  const _AdminNavItem({required this.icon, required this.label, required this.path});
}
