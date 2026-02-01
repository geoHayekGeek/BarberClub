import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/barber_ui_constants.dart';

/// Horizontal scroll gallery for barber photos.
/// 3–5 images visible, rounded corners, swipeable.
/// Hide entire section when imageUrls is empty.
class BarberGallery extends StatelessWidget {
  final List<String> imageUrls;

  const BarberGallery({
    super.key,
    required this.imageUrls,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final imageCacheWidth = (BarberUIConstants.galleryItemWidth * dpr).round();
    final imageCacheHeight = (BarberUIConstants.galleryItemHeight * dpr).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BarberUIConstants.horizontalGutter,
          ),
          child: Text(
            BarberStrings.galerie,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: BarberUIConstants.chipSpacing),
        SizedBox(
          height: BarberUIConstants.galleryItemHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: BarberUIConstants.horizontalGutter,
            ),
            itemCount: imageUrls.length,
            separatorBuilder: (_, __) => const SizedBox(
              width: BarberUIConstants.galleryItemSpacing,
            ),
            itemBuilder: (context, index) {
              final url = imageUrls[index];
              final isNetwork = url.startsWith('http');

              return ClipRRect(
                borderRadius: BorderRadius.circular(
                  BarberUIConstants.galleryItemBorderRadius,
                ),
                child: SizedBox(
                  width: BarberUIConstants.galleryItemWidth,
                  child: isNetwork
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          memCacheWidth: imageCacheWidth,
                          memCacheHeight: imageCacheHeight,
                          maxWidthDiskCache: imageCacheWidth,
                          maxHeightDiskCache: imageCacheHeight,
                          placeholder: (_, __) => _placeholder(),
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : Image.asset(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white24,
        ),
      ),
    );
  }
}
