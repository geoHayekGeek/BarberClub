import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/salon_providers.dart';
import '../widgets/salon_card.dart';

class SalonsListScreen extends ConsumerWidget {
  const SalonsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salonsAsync = ref.watch(salonsListProvider);
    
    // 1. Check if we are in "Offers Mode" (path /offres or query selectFor=offers)
    final state = GoRouterState.of(context);
    final isOfferSelection = state.uri.path == '/offres' || state.uri.queryParameters['selectFor'] == 'offers';

    return Scaffold(
      appBar: AppBar(
        // 2. Dynamic Title
        title: Text(isOfferSelection ? 'Nos offres' : 'Nos salons'),
      ),
      body: SafeArea(
        child: salonsAsync.when(
          data: (salons) {
            if (salons.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aucun salon disponible pour le moment.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                    textAlign: TextAlign.center,
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
                  onTap: () => context.push(isOfferSelection ? '/offres/${salon.id}' : '/salons/${salon.id}'),
                  // 3. Pass the flag to hide description
                  hideDescription: isOfferSelection,
                );
              },
            );
          },
          
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),

          error: (error, stackTrace) {
            final message = getSalonErrorMessage(error, stackTrace);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(salonsListProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}