import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/models/salon.dart';
import '../providers/salon_providers.dart';
import '../widgets/salon_gallery.dart';
import '../widgets/salon_info_row.dart';

/// Salon detail page.
/// Fetches salon by id; hero image, description, gallery, info block, map button, Offers button, CTA.
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
        final message = getSalonErrorMessage(error, stackTrace);
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
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDescription(context),
                const SizedBox(height: 24),
                _buildGallerySection(context),
                const SizedBox(height: 32),
                _buildInfoBlock(context),
                const SizedBox(height: 24),
                
                // 1. Map Button
                _buildMapButton(context),
                const SizedBox(height: 16), // Smaller gap between buttons
                
                // 2. NEW: Offers Button
                _buildOffersButton(context),
                const SizedBox(height: 16),
                
                // 3. Main CTA (Booking)
                _buildCtaButton(context),
                
                SizedBox(height: 32 + MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withOpacity(0.4),
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _SalonHeroImage(imageUrl: salon.images.isNotEmpty ? salon.images.first : null),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Text(
                salon.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        salon.descriptionLong,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: Colors.white.withOpacity(0.9),
          height: 1.55,
        ),
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
            'Galerie',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 12),
        SalonGallery(imageUrls: salon.images),
      ],
    );
  }

  Widget _buildInfoBlock(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          SalonInfoRow(
            icon: Icons.location_on_outlined,
            text: salon.address,
          ),
          SalonInfoRow(
            icon: Icons.schedule_outlined,
            text: salon.openingHours,
          ),
          if (salon.services.isNotEmpty)
            SalonInfoRow(
              icon: Icons.content_cut_outlined,
              text: salon.services.join(', '),
            ),
        ],
      ),
    );
  }

  // --- EXISTING MAP BUTTON ---
  Widget _buildMapButton(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () => _openMaps(context),
          icon: const Icon(Icons.map_outlined, size: 22),
          label: const Text('Voir sur Google Maps'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.6)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  // --- NEW OFFERS BUTTON ---
  Widget _buildOffersButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          // Navigate to offers filtered by this salon ID
          onPressed: () => context.push('/offres/${salon.id}'),
          icon: const Icon(Icons.local_offer_outlined, size: 22),
          label: const Text('Voir les offres du salon'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white, // White text to stand out
            side: const BorderSide(color: Colors.white30), // Subtle light border
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMaps(BuildContext context) async {
    final query = Uri.encodeComponent(salon.address);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir la carte')),
      );
    }
  }

Widget _buildCtaButton(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () async {
            // 1. Get the URL from the salon object
            final url = salon.timifyUrl;

            // 2. Check if URL exists
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

            // 3. Launch the URL
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
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Prendre RDV ici',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _SalonHeroImage extends StatelessWidget {
  final String? imageUrl;

  const _SalonHeroImage({this.imageUrl});

  static const String _placeholderAsset = 'assets/images/barber_background.jpg';

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: const Color(0xFF1A1A1A),
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Image.asset(
      _placeholderAsset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A1A)),
    );
  }
}