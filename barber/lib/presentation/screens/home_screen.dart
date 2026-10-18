import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/salon.dart';
import '../providers/salon_providers.dart';
import '../widgets/glowing_separator.dart';
import '../widgets/home_header.dart';

/// Home screen with a distinct intro hero then salon selection.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final viewportHeight = media.size.height;
    final salonsAsync = ref.watch(salonsListProvider);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: viewportHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _IntroBackground(
                    imageUrl: salonsAsync.valueOrNull?.firstOrNull?.imageUrl,
                  ),
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: HomeHeader(),
                  ),
                  _IntroCenterContent(
                    salonNames:
                        salonsAsync.valueOrNull
                            ?.map((salon) => salon.city)
                            .toList() ??
                        const [],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.black,
              child: salonsAsync.when(
                data: (salons) {
                  if (salons.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'Aucun salon disponible pour le moment.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      26,
                      0,
                      media.viewPadding.bottom + 140,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'NOS SALONS',
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(
                                      fontFamily: 'Orbitron',
                                      fontSize: 26,
                                      letterSpacing: 2.6,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Choisissez votre adresse BarberClub.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white70,
                                      height: 1.45,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SalonPanels(
                          salons: salons,
                          onTapSalon: (salon) =>
                              context.push('/salon/${salon.id}'),
                        ),
                        const SizedBox(height: 2),
                      ],
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  ),
                ),
                error: (error, stackTrace) {
                  final message = getSalonErrorMessage(error, stackTrace);
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Text(
                          message,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => ref.invalidate(salonsListProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reessayer'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroBackground extends StatelessWidget {
  const _IntroBackground({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null)
          Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF111111)),
          ),
        Container(color: Colors.black.withOpacity(0.62)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.22),
                  Colors.transparent,
                  Colors.black.withOpacity(0.74),
                ],
                stops: const [0.0, 0.38, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroCenterContent extends StatelessWidget {
  const _IntroCenterContent({required this.salonNames});
  final List<String> salonNames;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              AppConfig.resolvePublicAssetUrl(
                '/assets/images/common/logo-blanc.png',
              )!,
              width: math.min(width * 0.82, 300),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/barber_club_full_logo.png',
                width: math.min(width * 0.82, 300),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              salonNames.join(' · '),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 18,
                color: Colors.white.withOpacity(0.84),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 34),
            _HeroPrimaryButton(
              label: 'Reserver',
              onTap: () => context.go('/rdv'),
            ),
            const SizedBox(height: 16),
            const _ScrollHintIndicator(),
          ],
        ),
      ),
    );
  }
}

class _HeroPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _HeroPrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalonPanels extends StatelessWidget {
  final List<Salon> salons;
  final ValueChanged<Salon> onTapSalon;

  const _SalonPanels({required this.salons, required this.onTapSalon});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final squareSide = constraints.maxWidth;
        return Column(
          children: [
            for (var i = 0; i < salons.length; i++) ...[
              if (i > 0) const GlowingSeparator(),
              SizedBox(
                height: squareSide,
                child: _HeroSalonPanel(
                  key: ValueKey('home-salon-${salons[i].id}'),
                  salon: salons[i],
                  onTap: () => onTapSalon(salons[i]),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _HeroSalonPanel extends StatelessWidget {
  const _HeroSalonPanel({required this.salon, required this.onTap, super.key});

  final Salon salon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = AppConfig.resolveImageUrl(salon.imageUrl);
    final subtitle = salon.reservationSalonId == 'voiron'
        ? 'Barbershop premium à Voiron'
        : salon.location ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _SalonImageBackground(imageUrl: imageUrl),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.84),
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    salon.city.toUpperCase(),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _GlassCta(label: 'Decouvrir'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalonImageBackground extends StatelessWidget {
  final String? imageUrl;

  const _SalonImageBackground({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.startsWith('http')) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return _placeholder();
        },
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(Icons.store, size: 56, color: Colors.white24),
      ),
    );
  }
}

class _GlassCta extends StatelessWidget {
  final String label;

  const _GlassCta({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44, minWidth: 154),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.24), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Orbitron',
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 15, color: Colors.white),
        ],
      ),
    );
  }
}

class _ScrollHintIndicator extends StatefulWidget {
  const _ScrollHintIndicator();

  @override
  State<_ScrollHintIndicator> createState() => _ScrollHintIndicatorState();
}

class _ScrollHintIndicatorState extends State<_ScrollHintIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    _offsetAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Defiler',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _offsetAnimation,
            builder: (context, child) {
              final dy = 7 * _offsetAnimation.value;
              return Transform.translate(offset: Offset(0, dy), child: child);
            },
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
