import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/offer.dart';
import '../providers/offer_providers.dart';

/// Prestations / tarifs for a single salon. Requires salonId and salonName.
class SalonOffersDetailScreen extends ConsumerWidget {
  final String salonId;
  final String salonName;

  const SalonOffersDetailScreen({
    super.key,
    required this.salonId,
    required this.salonName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(prestationsListProvider(salonId));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: offersAsync.when(
          data: (offers) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  'PRESTATIONS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SALON DE ${salonName.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 3,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Text(
                      'NOS TARIFS',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.content_cut,
                              color: Colors.white.withOpacity(0.8),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'NOS PRESTATIONS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (offers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Aucune prestation pour le moment.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ),
                        )
                      else
                        ...offers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final offer = entry.value;
                          return Column(
                            key: ValueKey(offer.id),
                            children: [
                              _PrestationItem(offer: offer),
                              if (index < offers.length - 1)
                                Container(
                                  height: 1,
                                  margin: const EdgeInsets.symmetric(vertical: 16),
                                  color: Colors.white.withOpacity(0.05),
                                ),
                            ],
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur: $err',
                style: TextStyle(color: Colors.white.withOpacity(0.9)),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrestationItem extends StatelessWidget {
  const _PrestationItem({required this.offer});

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
