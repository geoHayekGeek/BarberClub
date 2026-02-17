import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/models/barber.dart';
import '../constants/barber_ui_constants.dart';

/// Full-width hero section: image, dark overlay, back arrow, name, level badge.
/// When [forSliverAppBar] is true, returns only the background content (no back
/// button) for use in [FlexibleSpaceBar.background].
class BarberHeroSection extends StatelessWidget {
  final Barber barber;
  final VoidCallback? onBack;

  /// Use [forSliverAppBar: true] when embedding in SliverAppBar.flexibleSpace.
  /// Back button is then provided by SliverAppBar.leading.
  const BarberHeroSection({
    super.key,
    required this.barber,
    this.onBack,
    this.forSliverAppBar = false,
  });

  /// When true, omits the back button (use SliverAppBar.leading instead).
  final bool forSliverAppBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final screenWidth = MediaQuery.of(context).size.width;
    final imageUrl = barber.image;
    final isNetwork = imageUrl != null && imageUrl.startsWith('http');
    final imageCacheWidth = (screenWidth * dpr).round();
    final imageCacheHeight = (BarberUIConstants.heroHeight * dpr).round();

    return SizedBox(
      height: BarberUIConstants.heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isNetwork)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: imageCacheWidth,
              memCacheHeight: imageCacheHeight,
              maxWidthDiskCache: imageCacheWidth,
              maxHeightDiskCache: imageCacheHeight,
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _placeholder(),
            )
          else
            _placeholder(),
          Container(
            color: Colors.black.withOpacity(BarberUIConstants.heroOverlayOpacity),
          ),
          if (!forSliverAppBar && onBack != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: Material(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    width: BarberUIConstants.backButtonMinSize,
                    height: BarberUIConstants.backButtonMinSize,
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: BarberUIConstants.horizontalGutter,
            right: BarberUIConstants.horizontalGutter,
            bottom: BarberUIConstants.sectionSpacing,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  barber.displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: BarberUIConstants.chipSpacing),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    BarberStrings.levelLabel(barber.level),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(Icons.person, size: 80, color: Colors.white24),
      ),
    );
  }
}
