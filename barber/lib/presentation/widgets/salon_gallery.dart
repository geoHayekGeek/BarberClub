import 'package:flutter/material.dart';

/// Horizontal scroll of salon photos (rounded thumbnails).
class SalonGallery extends StatelessWidget {
  final List<String> imagePaths;

  const SalonGallery({
    super.key,
    required this.imagePaths,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: imagePaths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.asset(
                imagePaths[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1A1A1A),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white24,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
