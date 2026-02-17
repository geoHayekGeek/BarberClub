import 'package:flutter/material.dart';
import '../../domain/models/offer.dart';

class OfferCard extends StatelessWidget {

  const OfferCard({super.key, required this.offer, required this.onTap});
  final Offer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Use BoxDecoration to create a solid, premium container
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A), // Deep charcoal background
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10, width: 1), // Subtle border
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Vertically centered
            crossAxisAlignment: CrossAxisAlignment.center, // Horizontally centered
            children: [
              // 1. Massive, Bold Price
              Text(
                '${offer.price}€',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36, // High-impact size
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 8),
              // 2. Centered, Professional Title
              Text(
                offer.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // 3. Subtle ID link (optional, for your internal tracking)
            ],
          ),
        ),
      ),
    );
  }
}