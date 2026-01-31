import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/barber_providers.dart';
import '../widgets/barber_card.dart';
import '../widgets/bottom_nav_bar.dart';

/// Nos Coiffeurs list page.
/// Fetches barbers from backend; loading / error / empty states.
class BarbersListScreen extends ConsumerWidget {
  const BarbersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barbersAsync = ref.watch(barbersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nos coiffeurs'),
      ),
      body: SafeArea(
        child: barbersAsync.when(
          data: (barbers) {
            if (barbers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aucun coiffeur disponible pour le moment.',
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
              itemCount: barbers.length,
              itemBuilder: (context, index) {
                final barber = barbers[index];
                return BarberCard(
                  barber: barber,
                  onTap: () => context.push('/coiffeurs/${barber.id}'),
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) {
            final message = getBarberErrorMessage(error, stackTrace);
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
                      onPressed: () => ref.invalidate(barbersListProvider),
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
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}
