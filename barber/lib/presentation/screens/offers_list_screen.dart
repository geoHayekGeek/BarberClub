import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/client_offer.dart';
import '../../domain/models/my_offer_item.dart';
import '../providers/offer_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/salon_providers.dart';
import '../widgets/offer_countdown_timer.dart';

/// Offres tab: client promotions with En cours / Packs / Permanentes / Mes offres.
class OffersListScreen extends ConsumerWidget {
  const OffersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: SafeArea(
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  'NOS OFFRES',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                ),
                const SizedBox(height: 16),
                TabBar(
                  isScrollable: true,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  labelColor: const Color(0xFFD4AF37),
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: const Color(0xFFD4AF37),
                  tabs: const [
                    Tab(text: 'En cours'),
                    Tab(text: 'Packs'),
                    Tab(text: 'Permanentes'),
                    Tab(text: 'Mes offres'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _EnCoursTab(),
                      _PacksTab(),
                      _PermanentesTab(),
                      _MesOffresTab(),
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

class _EnCoursTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(activeOffersProvider);
    final statesAsync = ref.watch(activationStatesProvider);

    return offersAsync.when(
      data: (offers) {
        final enCours = offers.where((o) => o.isEvent || o.isFlash).toList();
        if (enCours.isEmpty) {
          return _emptyState(context, 'Aucune offre en cours.');
        }
        return statesAsync.when(
          data: (states) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: enCours.length,
              itemBuilder: (context, i) {
                final offer = enCours[i];
                final status = states[offer.id] ?? '';
                return _EventFlashCard(
                  offer: offer,
                  activationStatus: status,
                  onRequestActivation: () => _requestActivation(context, ref, offer.id),
                );
              },
            );
          },
          loading: () => ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: enCours.length,
            itemBuilder: (context, i) => _EventFlashCard(
              offer: enCours[i],
              activationStatus: '',
              onRequestActivation: () => _requestActivation(context, ref, enCours[i].id),
            ),
          ),
          error: (_, __) => ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: enCours.length,
            itemBuilder: (context, i) => _EventFlashCard(
              offer: enCours[i],
              activationStatus: '',
              onRequestActivation: () => _requestActivation(context, ref, enCours[i].id),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white70)),
      error: (e, st) => _errorState(context, ref, e, st, activeOffersProvider),
    );
  }
}

class _PacksTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(activeOffersProvider);

    return offersAsync.when(
      data: (offers) {
        final packs = offers.where((o) => o.isPack).toList();
        if (packs.isEmpty) {
          return _emptyState(context, 'Aucun pack disponible.');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: packs.length,
          itemBuilder: (context, i) => _PackCard(offer: packs[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white70)),
      error: (e, st) => _errorState(context, ref, e, st, activeOffersProvider),
    );
  }
}

class _PermanentesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(activeOffersProvider);

    return offersAsync.when(
      data: (offers) {
        final permanent = offers.where((o) => o.isPermanent).toList();
        if (permanent.isEmpty) {
          return _emptyState(context, 'Aucune offre permanente.');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: permanent.length,
          itemBuilder: (context, i) => _PermanentCard(offer: permanent[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white70)),
      error: (e, st) => _errorState(context, ref, e, st, activeOffersProvider),
    );
  }
}

class _MesOffresTab extends ConsumerWidget {
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
          return _emptyState(context, 'Aucune offre activée.');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: items.length,
          itemBuilder: (context, i) => _MyOfferCard(item: items[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white70)),
      error: (e, st) => _errorState(context, ref, e, st, myOffersProvider),
    );
  }
}

Future<void> _requestActivation(BuildContext context, WidgetRef ref, String offerId) async {
  final repo = ref.read(offerRepositoryProvider);
  try {
    final result = await repo.requestActivation(offerId);
    ref.invalidate(myOffersProvider);
    ref.invalidate(activationStatesProvider);
    ref.invalidate(activeOffersProvider);
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
  AutoDisposeFutureProvider provider,
) {
  final message = getSalonErrorMessage(error, st);
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
            onPressed: () => ref.invalidate(provider),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

class _EventFlashCard extends StatelessWidget {
  const _EventFlashCard({
    required this.offer,
    required this.activationStatus,
    required this.onRequestActivation,
  });

  final ClientOffer offer;
  final String activationStatus;
  final VoidCallback onRequestActivation;

  @override
  Widget build(BuildContext context) {
    final imageUrl = AppConfig.resolveImageUrl(offer.imageUrl);

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
            if (imageUrl != null && imageUrl.startsWith('http'))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (imageUrl != null && imageUrl.startsWith('http')) const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    offer.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    offer.discountBadge,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (offer.description != null && offer.description!.trim().isNotEmpty)
              Text(
                offer.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (offer.isFlash && offer.maxSpots != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Places restantes: ${(offer.maxSpots! - offer.spotsTaken).clamp(0, offer.maxSpots!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: offer.maxSpots! > 0
                      ? (offer.spotsTaken / offer.maxSpots!).clamp(0.0, 1.0)
                      : 0,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                  minHeight: 6,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                OfferCountdownTimer(
                  endsAt: offer.endsAt,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _OfferCardButton(
                  activationStatus: activationStatus,
                  onRequestActivation: onRequestActivation,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferCardButton extends StatelessWidget {
  const _OfferCardButton({
    required this.activationStatus,
    required this.onRequestActivation,
  });

  final String activationStatus;
  final VoidCallback onRequestActivation;

  @override
  Widget build(BuildContext context) {
    final isUsed = activationStatus == 'used';
    final isActivated = activationStatus == 'activated';
    final isPendingScan = activationStatus == 'pending_scan';
    String label;
    if (isUsed) {
      label = 'Utilisée';
    } else if (isActivated) {
      label = 'Activée';
    } else if (isPendingScan) {
      label = 'En attente';
    } else {
      label = 'Activer';
    }
    return _GlassButton(
      label: label,
      isActivated: isActivated,
      showCheck: isActivated,
      onTap: isUsed ? null : (isActivated || isPendingScan ? null : onRequestActivation),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.offer});

  final ClientOffer offer;

  @override
  Widget build(BuildContext context) {
    final imageUrl = AppConfig.resolveImageUrl(offer.imageUrl);

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
            if (imageUrl != null && imageUrl.startsWith('http'))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (imageUrl != null && imageUrl.startsWith('http')) const SizedBox(height: 16),
            Text(
              offer.title,
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
            if (offer.description != null && offer.description!.trim().isNotEmpty)
              Text(
                offer.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (offer.discountType == 'percentage')
                  Text(
                    offer.discountBadge,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD4AF37),
                    ),
                  )
                else if (offer.discountType == 'fixed')
                  Text(
                    '${offer.discountValue}€',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

class _PermanentCard extends StatelessWidget {
  const _PermanentCard({required this.offer});

  final ClientOffer offer;

  @override
  Widget build(BuildContext context) {
    final imageUrl = AppConfig.resolveImageUrl(offer.imageUrl);

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
            if (imageUrl != null && imageUrl.startsWith('http'))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (imageUrl != null && imageUrl.startsWith('http')) const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    offer.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    offer.discountBadge,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (offer.description != null && offer.description!.trim().isNotEmpty)
              Text(
                offer.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

class _MyOfferCard extends StatelessWidget {
  const _MyOfferCard({required this.item});

  final MyOfferItem item;

  @override
  Widget build(BuildContext context) {
    final statusText = item.isActivated
        ? 'Activée en salon'
        : item.isUsed
            ? 'Utilisée'
            : item.isExpired
                ? 'Expirée'
                : item.status == 'pending_scan'
                    ? 'En attente validation'
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
                      color: Colors.white70,
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

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.label,
    this.onTap,
    this.isActivated = false,
    this.showCheck = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isActivated;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActivated ? const Color(0xFFD4AF37).withOpacity(0.5) : Colors.grey.withOpacity(0.45),
            width: 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isActivated
                ? [
                    const Color(0xFFD4AF37).withOpacity(0.15),
                    const Color(0xFFD4AF37).withOpacity(0.05),
                  ]
                : [
                    const Color(0xFF2A2A2A),
                    const Color(0xFF1F1F1F),
                  ],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActivated ? const Color(0xFFD4AF37) : Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                fontSize: 13,
              ),
            ),
            if (showCheck) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check, color: Color(0xFFD4AF37), size: 16),
            ] else if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward, color: Colors.white70, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}
