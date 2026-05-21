import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Header widget for Home screen
/// Displays centered crown with side actions.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  Future<void> _openUrl(
    BuildContext context,
    Uri uri, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    try {
      if (await launchUrl(uri, mode: mode)) {
        return;
      }
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
      );
    }
  }

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse('https://barberclub-grenoble.fr/');
    await _openUrl(context, uri);
  }

  Future<void> _openInstagram(BuildContext context) async {
    const instagramWeb = 'https://www.instagram.com/barberclub_grenoble';
    const instagramApp = 'instagram://user?username=barberclub_grenoble';

    try {
      if (await launchUrl(Uri.parse(instagramApp))) {
        return;
      }
    } catch (_) {}

    try {
      if (await launchUrl(
        Uri.parse(instagramWeb),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir Instagram')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                child: Row(
                  children: [
                    _HeaderAction(
                      onTap: () => _openWebsite(context),
                      icon: Icons.language,
                      tooltip: 'Site web',
                    ),
                    const SizedBox(width: 10),
                    _HeaderAction(
                      onTap: () => _openInstagram(context),
                      tooltip: 'Instagram',
                      child: FaIcon(
                        FontAwesomeIcons.instagram,
                        color: Colors.white.withOpacity(0.92),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Image.asset(
                  'assets/images/couronne_white.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                right: 0,
                child: _HeaderAction(
                  onTap: () => context.go('/compte'),
                  icon: Icons.person_outline,
                  tooltip: 'Mon compte',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? child;
  final String? tooltip;

  const _HeaderAction({
    required this.onTap,
    this.icon,
    this.child,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1,
              ),
            ),
            child: Center(
              child:
                  child ??
                  Icon(icon, color: Colors.white.withOpacity(0.92), size: 20),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return content;
    }

    return Tooltip(message: tooltip!, child: content);
  }
}
