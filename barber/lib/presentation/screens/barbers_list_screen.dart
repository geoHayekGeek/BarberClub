import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/barber_ui_constants.dart';
import '../providers/barber_providers.dart';
import '../widgets/barber_horizontal_card.dart';

/// Nos Coiffeurs list page.
/// Horizontal scrolling cards (carousel), one per coiffeur.
class BarbersListScreen extends ConsumerWidget {
  const BarbersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barbersAsync = ref.watch(barbersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(BarberStrings.pageTitle),
      ),
      body: SafeArea(
        child: barbersAsync.when(
          data: (barbers) {
            if (barbers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(BarberUIConstants.horizontalGutter),
                  child: Text(
                    BarberStrings.emptyList,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final carouselHeight =
                MediaQuery.of(context).size.height * BarberUIConstants.carouselHeightFraction;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: carouselHeight,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: BarberUIConstants.horizontalGutter,
                      vertical: BarberUIConstants.sectionSpacing,
                    ),
                    itemCount: barbers.length,
                    itemBuilder: (context, index) {
                      final barber = barbers[index];
                      return BarberHorizontalCard(
                        barber: barber,
                        onTap: () => context.push('/coiffeurs/${barber.id}'),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) {
            final message = getBarberErrorMessage(error, stackTrace);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(BarberUIConstants.horizontalGutter),
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
                    const SizedBox(height: BarberUIConstants.sectionSpacing),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(barbersListProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text(BarberStrings.retry),
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
