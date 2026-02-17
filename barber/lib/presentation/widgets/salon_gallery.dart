import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Placeholder asset when no image or error.
const String _kPlaceholderAsset = 'assets/images/barber_background.jpg';

/// Horizontal scroll of salon photos (rounded thumbnails).
/// Supports network URLs and asset paths.
class SalonGallery extends StatelessWidget {

  const SalonGallery({
    super.key,
    required this.imageUrls,
  });
  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: imageUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final url = imageUrls[index];
          final isNetwork = url.startsWith('http');

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: isNetwork
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
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
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white24,
      ),
    );
  }
}
