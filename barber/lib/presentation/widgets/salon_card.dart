import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Added for routing logic
import '../../domain/models/salon.dart';

/// Placeholder asset when no image or error.
const String _kPlaceholderAsset = 'assets/images/barber_background.jpg';

class SalonCard extends StatelessWidget {
  final Salon salon;
  
  // Note: We keep the onTap parameter for flexibility, 
  // but we can also handle internal navigation logic here.
  final VoidCallback onTap;

  const SalonCard({
    super.key,
    required this.salon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = salon.images.isNotEmpty ? salon.images.first : null;
    final isNetworkUrl = imageUrl != null && imageUrl.startsWith('http');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 1. Get the current route information
            final state = GoRouterState.of(context);
            final selectFor = state.uri.queryParameters['selectFor'];

            // 2. Decide where to go based on the menu selection
            if (selectFor == 'offers') {
              // Navigate to the filtered offers for this specific salon
              context.push('/offres/${salon.id}');
            } else {
              // Default behavior: call the provided onTap (usually salon details)
              onTap();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image Handling
                  if (isNetworkUrl)
                    CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _imageLoadingPlaceholder(),
                      errorWidget: (_, __, ___) => _placeholderImage(),
                    )
                  else
                    _placeholderImage(),
                  
                  // Dark Gradient Overlay
                  _buildGradientOverlay(),

                  // Content (City, Name, Description)
                  _buildCardContent(theme),

                  // Navigation Icon
                  _buildArrowIcon(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI Helper Methods to keep build() clean ---

  Widget _buildGradientOverlay() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.2),
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
      );

  Widget _buildCardContent(ThemeData theme) => Positioned(
        left: 20,
        right: 52,
        bottom: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              salon.city,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              salon.name,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              salon.descriptionShort,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.85),
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

  Widget _buildArrowIcon() => Positioned(
        right: 20,
        bottom: 0,
        top: 0,
        child: Center(
          child: Icon(
            Icons.arrow_forward_ios,
            size: 18,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      );

  Widget _imageLoadingPlaceholder() => Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _placeholderImage() => Image.asset(
        _kPlaceholderAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF1A1A1A),
        ),
      );
}