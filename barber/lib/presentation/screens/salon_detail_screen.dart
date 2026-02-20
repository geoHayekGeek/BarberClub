import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/salon.dart';
import '../providers/salon_providers.dart';

/// Salon detail: immersive header, premium info cards (Adresse, Téléphone, Horaires), gallery, CTA.
class SalonDetailScreen extends ConsumerWidget {
  final String salonId;

  const SalonDetailScreen({
    super.key,
    required this.salonId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salonAsync = ref.watch(salonDetailProvider(salonId));

    return salonAsync.when(
      data: (salon) => _SalonDetailContent(salon: salon),
      loading: () => Scaffold(
        backgroundColor: const Color(0xFF0E0E10),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: Colors.white70),
          ),
        ),
      ),
      error: (error, stackTrace) {
        final message = getSalonErrorMessage(error, stackTrace);
        return Scaffold(
          backgroundColor: const Color(0xFF0E0E10),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(salonDetailProvider(salonId)),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SalonDetailContent extends StatelessWidget {
  final Salon salon;

  const _SalonDetailContent({required this.salon});

  @override
  Widget build(BuildContext context) {
    final headerHeight = MediaQuery.of(context).size.height * 0.4;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: headerHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: () {
                      final resolved = AppConfig.resolveImageUrl(salon.imageUrl);
                      return resolved != null && resolved.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: resolved,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFF1A1A1A),
                              child: const Center(
                                  child: CircularProgressIndicator(color: Colors.white54)),
                            ),
                            errorWidget: (_, __, ___) => _heroPlaceholder(),
                          )
                        : _heroPlaceholder();
                    }(),
                  ),
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top,
                    left: 8,
                    child: Material(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(24),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 24,
                    child: Text(
                      salon.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (salon.descriptionLong.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        salon.descriptionLong,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 15,
                          height: 1.55,
                        ),
                      ),
                    ),
                  if (salon.descriptionLong.isNotEmpty) const SizedBox(height: 24),
                  _SalonInfoCard(
                    icon: Icons.location_on_outlined,
                    title: 'ADRESSE',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          salon.address,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: () => _openMaps(context),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.send_outlined, color: Colors.black87, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      'OUVRIR DANS MAPS',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SalonInfoCard(
                    icon: Icons.phone_outlined,
                    title: 'TÉLÉPHONE',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          salon.phone ?? 'Non renseigné',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: salon.phone != null && salon.phone!.isNotEmpty
                                  ? () => _callSalon(context)
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      color: salon.phone != null
                                          ? Colors.black87
                                          : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'APPELER LE SALON',
                                      style: TextStyle(
                                        color: salon.phone != null
                                            ? Colors.black87
                                            : Colors.grey,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HorairesCard(openingHours: salon.openingHours),
                  const SizedBox(height: 24),
                  _buildGallerySection(context),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/offres/${salon.id}'),
                        icon: const Icon(Icons.local_offer_outlined, size: 22),
                        label: const Text('Voir les offres du salon'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _launchTimify(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Prendre RDV ici',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 32 + MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallerySection(BuildContext context) {
    if (salon.images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'GALERIE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 4 / 3,
            ),
            itemCount: salon.images.length,
            itemBuilder: (context, index) {
              final url = AppConfig.resolveImageUrl(salon.images[index]);
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: url != null && url.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFF1A1A1A),
                          child: const Center(
                              child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2))),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFF1A1A1A),
                          child: const Icon(Icons.image_not_supported_outlined,
                              color: Colors.white24),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: Colors.white24),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openMaps(BuildContext context) async {
    final query = Uri.encodeComponent(salon.address);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir la carte')),
        );
      }
    }
  }

  Future<void> _callSalon(BuildContext context) async {
    if (salon.phone == null || salon.phone!.isEmpty) return;
    final uri = Uri.parse('tel:${salon.phone}');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le téléphone')),
        );
      }
    }
  }

  Future<void> _launchTimify(BuildContext context) async {
    final url = salon.timifyUrl;
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
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
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

  Widget _heroPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(Icons.store, size: 64, color: Colors.white24),
      ),
    );
  }
}

class _SalonInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SalonInfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

final _weekDays = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

List<({String day, String hours, bool isOpen})> _parseHoraires(String openingHours) {
  final result = <({String day, String hours, bool isOpen})>[];
  final lower = openingHours.toLowerCase();
  final sundayClosed = lower.contains('dim') && (lower.contains('ferm') || lower.contains('fermé'));
  for (int i = 0; i < 7; i++) {
    final isSunday = i == 6;
    if (isSunday && sundayClosed) {
      result.add((day: _weekDays[i], hours: 'Fermé', isOpen: false));
    } else {
      result.add((day: _weekDays[i], hours: '9h - 19h', isOpen: true));
    }
  }
  return result;
}

class _HorairesCard extends StatelessWidget {
  final String openingHours;

  const _HorairesCard({required this.openingHours});

  @override
  Widget build(BuildContext context) {
    final rows = _parseHoraires(openingHours);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.schedule_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'HORAIRES',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        row.day,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        row.hours,
                        style: TextStyle(
                          color: row.isOpen ? Colors.green : Colors.red,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
