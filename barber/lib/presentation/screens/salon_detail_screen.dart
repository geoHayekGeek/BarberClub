import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/models/salon.dart';
import '../widgets/salon_gallery.dart';
import '../widgets/salon_info_row.dart';

/// Salon detail page.
/// Hero image, description, gallery, info block, map button, CTA.
class SalonDetailScreen extends StatelessWidget {
  final Salon salon;

  const SalonDetailScreen({
    super.key,
    required this.salon,
  });

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
                _buildMapButton(context),
                const SizedBox(height: 24),
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
            Image.asset(
              salon.images.isNotEmpty
                  ? salon.images.first
                  : 'assets/images/barber_background.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1A1A1A),
              ),
            ),
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
        SalonGallery(imagePaths: salon.images),
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
          SalonInfoRow(
            icon: Icons.content_cut_outlined,
            text: salon.services.join(', '),
          ),
        ],
      ),
    );
  }

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
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bientôt disponible')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Prendre RDV ici'),
        ),
      ),
    );
  }
}
