import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Header widget for Home screen
/// Displays profile icon (left) and website/Instagram icons (right)
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  Future<void> _openUrl(BuildContext context, Uri uri, {LaunchMode mode = LaunchMode.externalApplication}) async {
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
    // Try Instagram app first, then fallback to browser
    const instagramWeb = 'https://www.instagram.com/barberclubgrenoble/';
    const instagramApp = 'instagram://user?username=barberclubgrenoble';

    try {
      if (await launchUrl(Uri.parse(instagramApp))) return;
    } catch (_) {}
    try {
      if (await launchUrl(Uri.parse(instagramWeb), mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir Instagram')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Profile icon (left)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/compte'),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: Colors.white.withOpacity(0.9),
                    size: 24,
                  ),
                ),
              ),
            ),
            // Website and Instagram icons (right)
            Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openWebsite(context),
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.language,
                        color: Colors.white.withOpacity(0.9),
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openInstagram(context),
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: Colors.white.withOpacity(0.9),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
