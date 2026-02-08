import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Fixes ConsumerWidget
import '../providers/offer_providers.dart';
import '../widgets/offer_card.dart'; // Fixes OfferCard


class OffersListScreen extends ConsumerWidget {
  final String? salonId;
  const OffersListScreen({super.key, this.salonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
final offersAsync = ref.watch(offersListProvider(salonId));

    return Scaffold(
      appBar: AppBar(title: const Text('Offres')),
      body: SafeArea(
        child: offersAsync.when(
       // lib/presentation/screens/offers_list_screen.dart

// lib/presentation/screens/offers_list_screen.dart

data: (offers) => GridView.builder(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: 16,
    crossAxisSpacing: 16,
    childAspectRatio: 0.9, // Lower value makes cards taller
  ),
  itemCount: offers.length,
  itemBuilder: (context, index) => OfferCard(
    offer: offers[index],
    onTap: () {},
  ),
),

      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur: $err')),

        ),
      ),
    );
  }
}