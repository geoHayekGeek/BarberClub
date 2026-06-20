import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/client_offer.dart';
import '../providers/auth_providers.dart';
import '../providers/offer_providers.dart';
import '../widgets/offer_public_card.dart';

class OffersListScreen extends ConsumerWidget {
  const OffersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final isAuthenticated =
        ref.watch(authStateProvider).status == AuthStatus.authenticated;
    final activationStates = ref
        .watch(activationStatesProvider)
        .maybeWhen(
          data: (states) => states,
          orElse: () => const <String, String>{},
        );
    final offersAsync = ref.watch(currentOffersProvider);

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            math.max(116.0, bottomInset + 104),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    'Offres',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.2,
                      color: Colors.white.withValues(alpha: 0.96),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Avantages & Événements',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 12.6,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.4,
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Restez connectés',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Des surprises et des événements exclusifs arrivent bientôt chez BarberClub Meylan. Suivez-nous pour ne rien rater.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.55,
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 28),
                  offersAsync.when(
                    data: (offers) {
                      if (offers.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Aucune offre active pour le moment.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.5,
                              color: Colors.white.withValues(alpha: 0.62),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < offers.length; i++) ...[
                            _OfferCard(
                              offer: offers[i],
                              activationStatus:
                                  activationStates[offers[i].id] ?? '',
                              isAuthenticated: isAuthenticated,
                              onLoginRequired: () =>
                                  context.go('/login?redirect=%2Foffres'),
                              onRequestActivation:
                                  offers[i].supportsQrActivation
                                  ? () => _requestActivation(
                                      context,
                                      ref,
                                      offers[i].id,
                                    )
                                  : null,
                            ),
                            if (i < offers.length - 1)
                              const SizedBox(height: 16),
                          ],
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white54),
                      ),
                    ),
                    error: (error, stackTrace) => _errorCard(
                      context,
                      ref,
                      error,
                      stackTrace,
                      (r) => r.invalidate(currentOffersProvider),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeading(title: 'Conditions'),
                  const SizedBox(height: 12),
                  const _ConditionItem(
                    text: "Non cumulable avec d'autres offres",
                  ),
                  const SizedBox(height: 10),
                  const _ConditionItem(
                    text: 'Valable sur réservation en ligne',
                  ),
                  const SizedBox(height: 10),
                  const _ConditionItem(text: '1 offre maximum par réservation'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const Color _pageBackground = Color(0xFF050505);

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.activationStatus,
    required this.isAuthenticated,
    required this.onLoginRequired,
    required this.onRequestActivation,
  });

  final ClientOffer offer;
  final String activationStatus;
  final bool isAuthenticated;
  final VoidCallback onLoginRequired;
  final Future<void> Function()? onRequestActivation;

  @override
  Widget build(BuildContext context) {
    return OfferPublicCard(
      key: ValueKey('offer-${offer.id}'),
      offer: offer,
      isUpcoming: false,
      activationStatus: activationStatus,
      onRequestActivation: onRequestActivation,
      onLoginRequired: onLoginRequired,
      isAuthenticated: isAuthenticated,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Orbitron',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
        color: Colors.white.withValues(alpha: 0.92),
      ),
    );
  }
}

class _ConditionItem extends StatelessWidget {
  const _ConditionItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _requestActivation(
  BuildContext context,
  WidgetRef ref,
  String offerId,
) async {
  final repo = ref.read(offerRepositoryProvider);
  try {
    final result = await repo.requestActivation(offerId);
    ref.invalidate(currentOffersProvider);
    ref.invalidate(activationStatesProvider);
    ref.invalidate(publicOffersFeedProvider);
    ref.invalidate(myOffersProvider);
    if (context.mounted && result.qrPayload.isNotEmpty) {
      await context.push(
        '/offres/activation-qr',
        extra: {'offerId': offerId, 'qrPayload': result.qrPayload},
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de demander l\'activation. Reessayez ou connectez-vous.',
          ),
          backgroundColor: Color(0xFF3C2323),
        ),
      );
    }
  }
}

Widget _errorCard(
  BuildContext context,
  WidgetRef ref,
  Object error,
  StackTrace st,
  void Function(WidgetRef r) retry,
) {
  final message = getOfferFeedErrorMessage(error, st);
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Erreur de chargement',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => retry(ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Reessayer'),
          ),
        ],
      ),
    ),
  );
}
