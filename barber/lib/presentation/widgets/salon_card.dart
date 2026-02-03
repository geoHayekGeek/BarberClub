import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/salon.dart';

const String _kPlaceholderAsset = 'assets/images/barber_background.jpg';

class SalonCard extends StatelessWidget {
  final Salon salon;
  final VoidCallback onTap;
  final bool hideDescription;

  const SalonCard({
    super.key,
    required this.salon,
    required this.onTap,
    this.hideDescription = false,
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
            final state = GoRouterState.of(context);
            final selectFor = state.uri.queryParameters['selectFor'];

            if (selectFor == 'offers') {
              context.push('/offres/${salon.id}');
            } else {
              onTap();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              // FIXED: Always use 16/9 to keep the cards big and immersive
              aspectRatio: 16 / 9, 
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isNetworkUrl)
                    CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _imageLoadingPlaceholder(),
                      errorWidget: (_, __, ___) => _placeholderImage(),
                    )
                  else
                    _placeholderImage(),
                  
                  _buildGradientOverlay(),
                  _buildCardContent(theme),
                  _buildArrowIcon(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.1), // Lighter top for better visibility
              Colors.black.withOpacity(0.8), // Darker bottom for text contrast
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
              salon.city.toUpperCase(), // Added uppercase for style
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                letterSpacing: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              salon.name,
              style: theme.textTheme.headlineSmall?.copyWith( // Slightly bigger font
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Only show description if hideDescription is FALSE
            if (!hideDescription) ...[
              const SizedBox(height: 8),
              Text(
                salon.descriptionShort,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      );

  Widget _buildArrowIcon() => Positioned(
        right: 20,
        bottom: 20, // Aligned with the text bottom
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.white,
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