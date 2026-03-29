import 'package:flutter/material.dart';

import '../../domain/models/offer.dart';

/// Single prestation row: title, optional description/duration, price.
class PrestationItem extends StatelessWidget {
  const PrestationItem({super.key, required this.offer});

  final Offer offer;

  String get _descriptionText {
    if (offer.description != null && offer.description!.trim().isNotEmpty) {
      return offer.description!;
    }
    if (offer.durationMinutes > 0) {
      return 'Durée: ${offer.durationMinutes} min';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.title,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_descriptionText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _descriptionText,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${offer.price}€',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
