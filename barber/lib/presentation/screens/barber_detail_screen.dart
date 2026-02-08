import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                padding: const EdgeInsets.all(BarberUIConstants.horizontalGutter),
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

  Widget _buildCtaButton(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: BarberUIConstants.ctaHeight,
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(BarberStrings.ctaSoon)),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BarberUIConstants.ctaBorderRadius),
          ),
        ),
        child: const Text(BarberStrings.ctaRdv),
      ),
    );
  }
}
