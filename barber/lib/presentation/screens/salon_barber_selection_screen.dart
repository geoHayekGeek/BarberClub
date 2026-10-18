import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/barber.dart';
import '../constants/barber_ui_constants.dart';
import '../providers/barber_providers.dart';

/// Nos Barbers tab entry:
/// Show each published salon's team. Salons are discovered from the website.
class SalonBarberSelectionScreen extends ConsumerWidget {
  const SalonBarberSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barbersAsync = ref.watch(barbersListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        bottom: false,
        child: barbersAsync.when(
          data: (barbers) {
            if (barbers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(
                    BarberUIConstants.horizontalGutter,
                  ),
                  child: Text(
                    BarberStrings.emptyList,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final salonNames = <String, String>{};
            final grouped = <String, List<Barber>>{};
            for (final barber in barbers) {
              for (final salon in barber.salons) {
                salonNames[salon.id] = salon.city.isNotEmpty
                    ? salon.city
                    : salon.name;
                (grouped[salon.id] ??= []).add(barber);
              }
            }
            final bottomPadding =
                MediaQuery.of(context).viewPadding.bottom + 120;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nos Barbers',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white70,
                                letterSpacing: 0.6,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                for (final group in grouped.entries) ...[
                  SliverToBoxAdapter(
                    child: _BarberCarouselSection(
                      title: salonNames[group.key]!.toUpperCase(),
                      barbers: group.value,
                      onTapBarber: (barber) =>
                          _openBarberDetails(context, barber, group.key),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                ],
                SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          ),
          error: (error, stackTrace) {
            final message = getBarberErrorMessage(error, stackTrace);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(
                  BarberUIConstants.horizontalGutter,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      message,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
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

  void _openBarberDetails(BuildContext context, Barber barber, String salonId) {
    final targetSalon = barber.salons.firstWhere(
      (salon) => salon.id == salonId,
    );
    final salonName = targetSalon.name;
    final encodedName = Uri.encodeComponent(salonName);
    context.push(
      '/coiffeurs/salon/$salonId/barber/${barber.id}?name=$encodedName',
    );
  }
}

class _BarberCarouselSection extends StatelessWidget {
  const _BarberCarouselSection({
    required this.title,
    required this.barbers,
    required this.onTapBarber,
  });

  final String title;
  final List<Barber> barbers;
  final ValueChanged<Barber> onTapBarber;

  @override
  Widget build(BuildContext context) {
    const carouselHeight = 356.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: carouselHeight,
          child: barbers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Center(
                      child: Text(
                        'Aucun barber pour le moment.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white60),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: barbers.length,
                  itemBuilder: (context, index) {
                    final barber = barbers[index];
                    return _BarberCarouselCard(
                      barber: barber,
                      onTap: () => onTapBarber(barber),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _BarberCarouselCard extends StatefulWidget {
  const _BarberCarouselCard({required this.barber, required this.onTap});

  final Barber barber;
  final VoidCallback onTap;

  @override
  State<_BarberCarouselCard> createState() => _BarberCarouselCardState();
}

class _BarberCarouselCardState extends State<_BarberCarouselCard> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(20));
    final imageUrl = AppConfig.resolveImageUrl(widget.barber.image);
    final city = widget.barber.salons.isNotEmpty
        ? widget.barber.salons.first.city
        : '';

    return SizedBox(
      width: 256,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _scale = 0.985),
            onTapUp: (_) => setState(() => _scale = 1),
            onTapCancel: () => setState(() => _scale = 1),
            onTap: widget.onTap,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              scale: _scale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: radius,
                    child: imageUrl != null && imageUrl.startsWith('http')
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.08),
                            Colors.black.withOpacity(0.38),
                            Colors.black.withOpacity(0.78),
                          ],
                          stops: const [0, 0.48, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.barber.displayName.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Orbitron',
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (city.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            city.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white24, size: 52),
      ),
    );
  }
}
