import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/barber.dart';
import '../constants/barber_ui_constants.dart';

/// Horizontal card for carousel-style barber list.
/// Fixed width, portrait image, name, city, optional summary, level badge.
class BarberHorizontalCard extends StatelessWidget {
  final Barber barber;
  final VoidCallback onTap;

  const BarberHorizontalCard({
    super.key,
    required this.barber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final imageUrl = AppConfig.resolveImageUrl(barber.image);
    final isNetworkUrl = imageUrl != null && imageUrl.startsWith('http');
    final salonCity = barber.salons.isNotEmpty ? barber.salons.first.city : '';
    final summary = barber.bio.isNotEmpty
        ? (barber.bio.length > 60 ? '${barber.bio.substring(0, 60)}...' : barber.bio)
        : null;
    final imageCacheWidth = (BarberUIConstants.cardWidth * dpr).round();
    final imageCacheHeight =
        ((BarberUIConstants.cardWidth / BarberUIConstants.cardImageAspectRatio) * dpr)
            .round();

    return SizedBox(
      width: BarberUIConstants.cardWidth,
      child: Padding(
        padding: const EdgeInsets.only(right: BarberUIConstants.cardSpacing),
        child: Material(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(BarberUIConstants.cardBorderRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(BarberUIConstants.cardBorderRadius),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BarberUIConstants.cardBorderRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: BarberUIConstants.cardImageAspectRatio,
                    child: isNetworkUrl
                        ? CachedNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: imageCacheWidth,
                            memCacheHeight: imageCacheHeight,
                            maxWidthDiskCache: imageCacheWidth,
                            maxHeightDiskCache: imageCacheHeight,
                            placeholder: (_, __) => _buildPlaceholder(),
                            errorWidget: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(BarberUIConstants.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          barber.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (salonCity.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            salonCity,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (summary != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            summary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              BarberStrings.levelLabel(barber.level),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white24, size: 48),
      ),
    );
  }
}
