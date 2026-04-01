import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/my_offer_item.dart';
import '../providers/offer_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/offer_countdown_timer.dart';
import '../widgets/offer_public_card.dart';

/// Offres tab: Offres en cours, Offres à venir, Mes offres.
class OffersListScreen extends ConsumerWidget {
  const OffersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: SafeArea(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  'Nos offres',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 16),
                TabBar(
                  isScrollable: true,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                  labelColor: const Color(0xFFD4AF37),
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: const Color(0xFFD4AF37),
                  tabs: const [
                    Tab(text: 'Offres en cours'),
                    Tab(text: 'Offres à venir'),
                    Tab(text: 'Mes offres'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      const _OffresEnCoursTab(),
                      const _OffresAVenirTab(),
                      const _MesOffresTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OffresEnCoursTab extends ConsumerWidget {
  const _OffresEnCoursTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(currentOffersProvider);
    final statesAsync = ref.watch(activationStatesProvider);

    return offersAsync.when(
      data: (offers) {
        if (offers.isEmpty) {
          return _emptyState(context, 'Aucune offre en cours pour le moment.');
        }
        return statesAsync.when(
          data: (states) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: offers.length,
              itemBuilder: (context, i) {
                final offer = offers[i];
                final status = states[offer.id] ?? '';
                return OfferPublicCard(
                  key: ValueKey('current-${offer.id}'),
                  offer: offer,
                  isUpcoming: false,
                  activationStatus: status,
                  onRequestActivation: offer.supportsQrActivation
                      ? () => _requestActivation(context, ref, offer.id)
                      : null,
                );
              },
            );
          },
          loading: () => ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: offers.length,
            itemBuilder: (context, i) => OfferPublicCard(
              key: ValueKey('current-loading-${offers[i].id}'),
              offer: offers[i],
              isUpcoming: false,
              activationStatus: '',
              onRequestActivation: offers[i].supportsQrActivation
                  ? () => _requestActivation(context, ref, offers[i].id)
                  : null,
            ),
          ),
          error: (_, __) => ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: offers.length,
            itemBuilder: (context, i) => OfferPublicCard(
              key: ValueKey('current-err-${offers[i].id}'),
              offer: offers[i],
              isUpcoming: false,
              activationStatus: '',
              onRequestActivation: offers[i].supportsQrActivation
                  ? () => _requestActivation(context, ref, offers[i].id)
                  : null,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white70)),
      error: (e, st) => _errorState(context, ref, e, st, (r) => r.invalidate(currentOffersProvider)),
    );
  }
}

class _OffresAVenirTab extends ConsumerWidget {
  const _OffresAVenirTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(upcomingOffersProvider);

    return offersAsync.when(
      data: (offers) {
        if (offers.isEmpty) {
          return _emptyState(context, 'Aucune offre à venir pour le moment.');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: offers.length,
          itemBuilder: (context, i) {
            final offer = offers[i];
            return OfferPublicCard(
              key: ValueKey('upcoming-${offer.id}'),
              offer: offer,
              isUpcoming: true,
              activationStatus: '',
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white70)),
      error: (e, st) => _errorState(context, ref, e, st, (r) => r.invalidate(upcomingOffersProvider)),
    );
  }
}

class _MesOffresTab extends ConsumerWidget {
  const _MesOffresTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final myOffersAsync = ref.watch(myOffersProvider);

    if (authState.status != AuthStatus.authenticated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Connectez-vous pour accéder à vos offres activées.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return myOffersAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return _emptyState(context, 'Aucune offre activée pour le moment.');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: items.length,
          itemBuilder: (context, i) => _MyOfferCard(item: items[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white70)),
      error: (e, st) => _errorState(context, ref, e, st, (r) => r.invalidate(myOffersProvider)),
    );
  }
}

Future<void> _requestActivation(BuildContext context, WidgetRef ref, String offerId) async {
  final repo = ref.read(offerRepositoryProvider);
  try {
    final result = await repo.requestActivation(offerId);
    ref.invalidate(myOffersProvider);
    ref.invalidate(activationStatesProvider);
    ref.invalidate(publicOffersFeedProvider);
    ref.invalidate(currentOffersProvider);
    ref.invalidate(upcomingOffersProvider);
    if (context.mounted && result.qrPayload.isNotEmpty) {
      context.push('/offres/activation-qr', extra: {'offerId': offerId, 'qrPayload': result.qrPayload});
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de demander l\'activation. Réessayez ou connectez-vous.'),
          backgroundColor: Color(0xFF5A2A2A),
        ),
      );
    }
  }
}

Widget _emptyState(BuildContext context, String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

Widget _errorState(
  BuildContext context,
  WidgetRef ref,
  Object error,
  StackTrace st,
  void Function(WidgetRef r) retry,
) {
  final message = getOfferFeedErrorMessage(error, st);
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => retry(ref),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

class _MyOfferCard extends StatelessWidget {
  const _MyOfferCard({required this.item});

  final MyOfferItem item;

  @override
  Widget build(BuildContext context) {
    final statusText = item.isActivated
        ? 'Offre activée'
        : item.isUsed
            ? 'Utilisée'
            : item.isExpired
                ? 'Expirée'
                : item.status == 'pending_scan'
                    ? 'En attente de validation'
                    : 'Annulée';
    final subtitle = item.isActivated
        ? 'Utilisable lors de votre prochaine réservation.'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.offer.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            if (item.offer.description != null && item.offer.description!.trim().isNotEmpty)
              Text(
                item.offer.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isActivated
                        ? const Color(0xFFD4AF37).withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: item.isActivated ? const Color(0xFFD4AF37) : Colors.white70,
                    ),
                  ),
                ),
                const Spacer(),
                if (item.expiresAt != null && item.isActivated)
                  OfferCountdownTimer(
                    endsAt: item.expiresAt,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
