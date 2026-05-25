import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/my_offer_item.dart';
import '../providers/auth_providers.dart';
import '../providers/offer_providers.dart';
import '../widgets/offer_countdown_timer.dart';
import '../widgets/offer_public_card.dart';

/// Offres tab: Offres en cours, Offres a venir, Mes offres.
class OffersListScreen extends ConsumerWidget {
  const OffersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    if (authState.status != AuthStatus.authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Offres')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Vous êtes en mode invité.\nConnectez-vous pour accéder aux offres exclusives et aux avantages premium.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: () => context.go('/login?redirect=%2Foffres'),
                      child: const Text('Se connecter'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF050505), Color(0xFF000000), Color(0xFF000000)],
            stops: [0.0, 0.32, 1.0],
          ),
        ),
        child: SafeArea(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/barber_club_full_logo.png',
                        height: 34,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.025),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.07),
                          ),
                        ),
                        child: Text(
                          'Des surprises et des evenements exclusifs arrivent bientot chez BarberClub.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withOpacity(0.56),
                                letterSpacing: 0.18,
                                height: 1.35,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: TabBar(
                      isScrollable: false,
                      tabAlignment: TabAlignment.fill,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: EdgeInsets.zero,
                      dividerColor: Colors.transparent,
                      splashBorderRadius: BorderRadius.circular(12),
                      labelPadding: EdgeInsets.zero,
                      indicator: BoxDecoration(
                        color: Colors.white.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.16),
                        ),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white38,
                      labelStyle: const TextStyle(
                        fontSize: 10.8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        fontFamily: 'Orbitron',
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 10.8,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.18,
                        fontFamily: 'Orbitron',
                      ),
                      tabs: const [
                        Tab(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text('Offres en cours'),
                          ),
                        ),
                        Tab(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text('Offres a venir'),
                          ),
                        ),
                        Tab(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text('Mes offres'),
                          ),
                        ),
                      ],
                    ),
                  ),
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
    final isAuthenticated =
        ref.watch(authStateProvider).status == AuthStatus.authenticated;
    final offersAsync = ref.watch(currentOffersProvider);
    final statesAsync = ref.watch(activationStatesProvider);

    return offersAsync.when(
      data: (offers) {
        if (offers.isEmpty) {
          return _emptyState(
            context,
            title: 'Aucune offre active',
            message: 'Aucune offre en cours pour le moment.',
          );
        }
        return statesAsync.when(
          data: (states) {
            return ListView.builder(
              padding: _tabListPadding(context),
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
                  isAuthenticated: isAuthenticated,
                  onLoginRequired: () =>
                      context.go('/login?redirect=%2Foffres'),
                );
              },
            );
          },
          loading: () => ListView.builder(
            padding: _tabListPadding(context),
            itemCount: offers.length,
            itemBuilder: (context, i) => OfferPublicCard(
              key: ValueKey('current-loading-${offers[i].id}'),
              offer: offers[i],
              isUpcoming: false,
              activationStatus: '',
              onRequestActivation: offers[i].supportsQrActivation
                  ? () => _requestActivation(context, ref, offers[i].id)
                  : null,
              isAuthenticated: isAuthenticated,
              onLoginRequired: () => context.go('/login?redirect=%2Foffres'),
            ),
          ),
          error: (_, __) => ListView.builder(
            padding: _tabListPadding(context),
            itemCount: offers.length,
            itemBuilder: (context, i) => OfferPublicCard(
              key: ValueKey('current-err-${offers[i].id}'),
              offer: offers[i],
              isUpcoming: false,
              activationStatus: '',
              onRequestActivation: offers[i].supportsQrActivation
                  ? () => _requestActivation(context, ref, offers[i].id)
                  : null,
              isAuthenticated: isAuthenticated,
              onLoginRequired: () => context.go('/login?redirect=%2Foffres'),
            ),
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white70)),
      error: (e, st) => _errorState(
        context,
        ref,
        e,
        st,
        (r) => r.invalidate(currentOffersProvider),
      ),
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
          return _emptyState(
            context,
            title: 'Aucune offre planifiee',
            message: 'Aucune offre a venir pour le moment.',
          );
        }
        return ListView.builder(
          padding: _tabListPadding(context),
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
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white70)),
      error: (e, st) => _errorState(
        context,
        ref,
        e,
        st,
        (r) => r.invalidate(upcomingOffersProvider),
      ),
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
      return _emptyState(
        context,
        title: 'Connexion requise',
        message: 'Connectez-vous pour acceder a vos offres activees.',
      );
    }

    return myOffersAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return _emptyState(
            context,
            title: 'Aucune offre activee',
            message: 'Vos offres activees apparaitront ici.',
          );
        }
        return ListView.builder(
          padding: _tabListPadding(context),
          itemCount: items.length,
          itemBuilder: (context, i) => _MyOfferCard(item: items[i]),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white70)),
      error: (e, st) => _errorState(
        context,
        ref,
        e,
        st,
        (r) => r.invalidate(myOffersProvider),
      ),
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
    ref.invalidate(myOffersProvider);
    ref.invalidate(activationStatesProvider);
    ref.invalidate(publicOffersFeedProvider);
    ref.invalidate(currentOffersProvider);
    ref.invalidate(upcomingOffersProvider);
    if (context.mounted && result.qrPayload.isNotEmpty) {
      context.push(
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

EdgeInsets _tabListPadding(BuildContext context) {
  final bottomInset = MediaQuery.of(context).viewPadding.bottom;
  final bottom = math.max(116.0, bottomInset + 104);
  return EdgeInsets.fromLTRB(16, 12, 16, bottom);
}

Widget _emptyState(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 26,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
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
                color: Colors.white.withOpacity(0.62),
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                color: Colors.white.withOpacity(0.62),
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => retry(ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.25)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: const Text('Reessayer'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _myOfferTypeLabelFr(MyOfferItem item) {
  final t = item.offer.type.toLowerCase();
  if (t == 'flash') return 'Offre flash';
  if (t == 'pack') return 'Pack';
  if (t == 'permanent') return 'Offre permanente';
  if (t == 'event') return 'Evenement';
  return item.offer.type;
}

class _MyOfferCard extends StatefulWidget {
  const _MyOfferCard({required this.item});

  final MyOfferItem item;

  @override
  State<_MyOfferCard> createState() => _MyOfferCardState();
}

class _MyOfferCardState extends State<_MyOfferCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holoController;
  late final Animation<double> _holoShift;

  @override
  void initState() {
    super.initState();
    _holoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _holoShift = CurvedAnimation(
      parent: _holoController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _holoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final statusText = item.isActivated
        ? 'Offre activee'
        : item.isUsed
        ? 'Utilisee'
        : item.isExpired
        ? 'Expiree'
        : item.status == 'pending_scan'
        ? 'En attente de validation'
        : 'Annulee';

    final subtitle = item.isActivated
        ? 'Utilisable lors de votre prochaine reservation.'
        : null;

    final statusBg = item.isActivated
        ? Colors.white.withOpacity(0.14)
        : Colors.white.withOpacity(0.08);
    final statusFg = item.isActivated ? Colors.white : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF090909),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.02),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _holoShift,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _HoloSweepPainter(progress: _holoShift.value),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IgnorePointer(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.03),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MiniChip(
                        label: _myOfferTypeLabelFr(item).toUpperCase(),
                        foreground: Colors.white70,
                        background: Colors.white.withOpacity(0.06),
                      ),
                      _MiniChip(
                        label: statusText.toUpperCase(),
                        foreground: statusFg,
                        background: statusBg,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.14),
                          ),
                        ),
                        child: Text(
                          '-${item.offer.discountValue}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.offer.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.offer.description != null &&
                      item.offer.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.offer.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.72),
                        height: 1.45,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withOpacity(0.6),
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: item.expiresAt != null && item.isActivated
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 15,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OfferCountdownTimer(
                                        endsAt: item.expiresAt,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.72),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoloSweepPainter extends CustomPainter {
  const _HoloSweepPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cardRect = Offset.zero & size;
    final xOffset = -2.0 * size.width * progress;
    final shaderRect = Rect.fromLTWH(
      xOffset,
      -size.height,
      size.width * 3.0,
      size.height * 3.0,
    );
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x26FFFFFF),
          Color(0x00FFFFFF),
          Color(0x14FFFFFF),
          Color(0x00FFFFFF),
          Color(0x1AFFFFFF),
        ],
        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(shaderRect);
    canvas.drawRect(cardRect, paint);
  }

  @override
  bool shouldRepaint(covariant _HoloSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.55,
        ),
      ),
    );
  }
}
