import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/salon_providers.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/salon_card.dart';

class SalonsListScreen extends ConsumerWidget {
  const SalonsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salonsAsync = ref.watch(salonsListProvider);
    
    // 1. Check if we are in "Offers Mode"
    // We read the query parameter to decide how the screen should look
    final state = GoRouterState.of(context);
    final isOfferSelection = state.uri.queryParameters['selectFor'] == 'offers';

    return Scaffold(
      appBar: AppBar(
        // 2. Dynamic Title: "Nos offres" if selecting for offers, else "Nos salons"
        title: Text(isOfferSelection ? 'Choisissez votre salon' : 'Nos salons'),
      ),
      body: SafeArea(
        child: salonsAsync.when(
          data: (salons) {
            if (salons.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aucun salon disponible.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: salons.length,
              itemBuilder: (context, index) {
                final salon = salons[index];
                return SalonCard(
                  salon: salon,
                  // We keep the navigation logic as is (it's handled inside the card or here)
                  onTap: () => context.push('/salons/${salon.id}'),
                  // 3. Pass the flag to hide description
                  hideDescription: isOfferSelection,
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erreur: $error')),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}