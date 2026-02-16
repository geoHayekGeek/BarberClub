import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart'; // <--- Added for links

import '../../domain/models/barber.dart';
import '../constants/barber_ui_constants.dart';
import '../providers/barber_providers.dart';
import '../widgets/barber_gallery.dart';
import '../widgets/barber_hero_section.dart';
import '../widgets/barber_interest_chips.dart';

/// Profil coiffeur (barber detail) page.
/// Hero, bio, centres d'intérêt, gallery, CTA.
class BarberDetailScreen extends ConsumerWidget {
  final String barberId;

  const BarberDetailScreen({
    super.key,
    required this.barberId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberAsync = ref.watch(barberDetailProvider(barberId));

    return barberAsync.when(
      data: (barber) => _BarberDetailContent(barber: barber),
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stackTrace) {
        final message = getBarberErrorMessage(error, stackTrace);
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(BarberUIConstants.horizontalGutter),
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
                    const SizedBox(height: BarberUIConstants.sectionSpacing),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.invalidate(barberDetailProvider(barberId)),
                      icon: const Icon(Icons.refresh),
                      label: const Text(BarberStrings.retry),
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

class _BarberDetailContent extends StatelessWidget {
  final Barber barber;

  const _BarberDetailContent({required this.barber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: BarberUIConstants.heroHeight,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.4),
                foregroundColor: Colors.white,
                minimumSize: const Size(BarberUIConstants.backButtonMinSize,
                    BarberUIConstants.backButtonMinSize),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: BarberHeroSection(
                barber: barber,
                forSliverAppBar: true,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: BarberUIConstants.sectionSpacing),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BarberUIConstants.horizontalGutter,
                  ),
                  child: _buildBio(context),
                ),
                const SizedBox(height: BarberUIConstants.sectionSpacing),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BarberUIConstants.horizontalGutter,
                  ),
                  child: BarberInterestChips(interests: barber.specialties),
                ),
                if (barber.galleryImages.isNotEmpty) ...[
                  const SizedBox(height: BarberUIConstants.sectionSpacing),
                  BarberGallery(imageUrls: barber.galleryImages),
                ],
                const SizedBox(height: BarberUIConstants.sectionSpacing),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BarberUIConstants.horizontalGutter,
                  ),
                  child: _buildCtaButton(context),
                ),
                SizedBox(
                  height: 32 + MediaQuery.of(context).padding.bottom,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBio(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      barber.bio,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: Colors.white.withOpacity(0.9),
        height: 1.55,
      ),
    );
  }

  // --- UPDATED CTA BUTTON ---
  Widget _buildCtaButton(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: BarberUIConstants.ctaHeight,
      child: ElevatedButton(
        onPressed: () => _handleBooking(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(BarberUIConstants.ctaBorderRadius),
          ),
        ),
        child: const Text(
          'Prendre RDV avec ce coiffeur',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // --- BOOKING LOGIC ---
  void _handleBooking(BuildContext context) {
    if (barber.salons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun salon associé à ce coiffeur.')),
      );
      return;
    }

    // CASE 1: Single Salon -> Open directly
    if (barber.salons.length == 1) {
      _launchTimify(context, barber.salons.first.timifyUrl);
      return;
    }

    // CASE 2: Multiple Salons -> Show Bottom Sheet to choose
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Où voulez-vous prendre RDV ?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...barber.salons.map((salon) => ListTile(
                  leading: const Icon(Icons.storefront, color: Colors.white70),
                  title: Text(
                    '${salon.name} (${salon.city})',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.white54),
                  onTap: () {
                    Navigator.pop(ctx); // Close sheet
                    _launchTimify(context, salon.timifyUrl);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- URL LAUNCHER ---
  Future<void> _launchTimify(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réservation en ligne indisponible pour ce lieu.'),
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
          const SnackBar(content: Text('Impossible d\'ouvrir le lien.')),
        );
      }
    }
  }
}