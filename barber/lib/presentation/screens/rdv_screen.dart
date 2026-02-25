import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/glowing_separator.dart';
import '../../core/config/app_config.dart';
import '../../domain/models/salon.dart';
import '../providers/salon_providers.dart';
import '../widgets/app_primary_button.dart';

class RdvScreen extends ConsumerWidget {
  const RdvScreen({super.key});

  Future<void> _launchTimify(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réservation en ligne indisponible pour ce salon.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir le lien de réservation.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salonsAsync = ref.watch(salonsListProvider);
    final selectedId = ref.watch(selectedSalonIdForRdvProvider);

    if (selectedId != null && salonsAsync.hasValue) {
      final salons = salonsAsync.value!;
      Salon? salon;
      for (final s in salons) {
        if (s.id == selectedId) {
          salon = s;
          break;
        }
      }
      if (salon != null) {
        final timifyUrl = salon.timifyUrl;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(selectedSalonIdForRdvProvider.notifier).state = null;
          _launchTimify(context, timifyUrl);
        });
      }
    }

    final sectionHeight = MediaQuery.of(context).size.height * 0.5;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: salonsAsync.when(
          data: (salons) {
            if (salons.isEmpty) {
              return const Center(
                child: Text('Aucun salon disponible.', style: TextStyle(color: Colors.white)),
              );
            }
            return SingleChildScrollView(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // LAYER 1: The Content Sections
                  Column(
                    children: [
                      for (final salon in salons)
                        _RdvSalonSectionWidget(
                          salon: salon,
                          height: sectionHeight,
                          onReserve: () => _launchTimify(context, salon.timifyUrl),
                        ),
                    ],
                  ),
                  
                  // LAYER 2: The Floating Separators (Z-Index fix)
                  // FIX: Using absolute positioning instead of a Column to prevent height overflow
                  for (int i = 1; i < salons.length; i++)
                    Positioned(
                      // Places the separator exactly on the physical boundary between images
                      // The -2 perfectly centers the 4px height of the GlowingSeparator
                      top: (i * sectionHeight) - 2, 
                      left: 0,
                      right: 0,
                      child: const IgnorePointer(
                        child: GlowingSeparator(),
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (err, _) => Center(child: Text('Erreur: $err', style: const TextStyle(color: Colors.white))),
        ),
      ),
    );
  }
}

class _RdvSalonSectionWidget extends StatelessWidget {
  final Salon salon;
  final double height;
  final VoidCallback onReserve;

  const _RdvSalonSectionWidget({
    required this.salon,
    required this.height,
    required this.onReserve,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = AppConfig.resolveImageUrl(salon.imageUrl);

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF1A1A1A))),
          Positioned.fill(
            child: imageUrl != null && imageUrl.startsWith('http')
                ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.4), Colors.black.withOpacity(0.85)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24, bottom: 60, right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  salon.name.toUpperCase(),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 3, color: Colors.white),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                AppPrimaryButton(label: 'RÉSERVER', onTap: onReserve),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(color: const Color(0xFF1A1A1A), child: const Icon(Icons.store, size: 64, color: Colors.white24));
}