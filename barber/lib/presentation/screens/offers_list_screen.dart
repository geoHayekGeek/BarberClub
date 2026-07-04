import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OffersListScreen extends StatefulWidget {
  const OffersListScreen({super.key});

  @override
  State<OffersListScreen> createState() => _OffersListScreenState();
}

enum _OffersTab { current, upcoming }

class _OffersListScreenState extends State<OffersListScreen> {
  _OffersTab _selectedTab = _OffersTab.current;
  late final DateTime _teaserRevealAt;

  @override
  void initState() {
    super.initState();
    _teaserRevealAt = DateTime.now().add(
      const Duration(days: 5, hours: 23, minutes: 57, seconds: 42),
    );
  }

  void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          const Positioned.fill(child: _OffersBackdrop()),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                math.max(128.0, bottomInset + 112),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _OffersHeader(onBack: () => _goBack(context)),
                      const SizedBox(height: 16),
                      _OffersTabSwitcher(
                        selected: _selectedTab,
                        onChanged: (tab) => setState(() => _selectedTab = tab),
                      ),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _selectedTab == _OffersTab.current
                            ? _CurrentOffersSection(
                                key: const ValueKey('current'),
                                onReserveTap: () => context.go('/rdv'),
                                onGiftTap: () => context.go('/rdv'),
                              )
                            : _UpcomingOffersSection(
                                key: const ValueKey('upcoming'),
                                revealAt: _teaserRevealAt,
                                onAlertTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Vous serez alerté !'),
                                      backgroundColor: Color(0xFF1A1A1A),
                                    ),
                                  );
                                },
                                onGiftTap: () => context.go('/rdv'),
                              ),
                      ),
                      const SizedBox(height: 28),
                      const _ConditionsSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const Color _pageBackground = Color(0xFF050505);

class _OffersBackdrop extends StatelessWidget {
  const _OffersBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF19160D),
            Color(0xFF060606),
            Color(0xFF050505),
            Color(0xFF151207),
          ],
          stops: [0.0, 0.22, 0.76, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.1,
                  colors: [
                    Color(0x332D2812),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 1.15,
                  colors: [
                    Color(0x26261E0B),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OffersHeader extends StatelessWidget {
  const _OffersHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBubbleButton(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
        ),
        const Spacer(),
        Image.asset(
          'assets/images/barber_club_full_logo.png',
          height: 28,
          fit: BoxFit.contain,
        ),
        const Spacer(),
        const SizedBox(width: 40, height: 40),
      ],
    );
  }
}

class _OffersTabSwitcher extends StatelessWidget {
  const _OffersTabSwitcher({
    required this.selected,
    required this.onChanged,
  });

  final _OffersTab selected;
  final ValueChanged<_OffersTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'OFFRE EN COURS',
              icon: Icons.circle,
              isActive: selected == _OffersTab.current,
              onTap: () => onChanged(_OffersTab.current),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _TabButton(
              label: 'OFFRE À VENIR',
              icon: Icons.schedule_rounded,
              isActive: selected == _OffersTab.upcoming,
              onTap: () => onChanged(_OffersTab.upcoming),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.30)
                  : Colors.transparent,
            ),
            color: isActive
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.02),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isActive ? 9 : 14,
                color: Colors.white.withValues(alpha: isActive ? 0.9 : 0.35),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.9,
                    color: Colors.white.withValues(
                      alpha: isActive ? 0.96 : 0.24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentOffersSection extends StatelessWidget {
  const _CurrentOffersSection({
    required this.onReserveTap,
    required this.onGiftTap,
    super.key,
  });

  final VoidCallback onReserveTap;
  final VoidCallback onGiftTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('current-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel(text: 'CHAQUE MARDI'),
        const SizedBox(height: 14),
        _CurrentPromoCard(onReserveTap: onReserveTap),
        const SizedBox(height: 40),
        const _SectionLabel(text: 'TOUTE L\'ANNEE'),
        const SizedBox(height: 14),
        _GiftCard(onTap: onGiftTap),
      ],
    );
  }
}

class _UpcomingOffersSection extends StatelessWidget {
  const _UpcomingOffersSection({
    required this.revealAt,
    required this.onAlertTap,
    required this.onGiftTap,
    super.key,
  });

  final DateTime revealAt;
  final VoidCallback onAlertTap;
  final VoidCallback onGiftTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('upcoming-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel(text: 'BIENTÔT'),
        const SizedBox(height: 14),
        _UpcomingTeaserCard(
          revealAt: revealAt,
          onAlertTap: onAlertTap,
        ),
        const SizedBox(height: 40),
        const _SectionLabel(text: 'TOUTE L\'ANNÉE'),
        const SizedBox(height: 14),
        _GiftCard(onTap: onGiftTap),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Orbitron',
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 3.5,
        color: Colors.white.withValues(alpha: 0.24),
      ),
    );
  }
}

class _CurrentPromoCard extends StatelessWidget {
  const _CurrentPromoCard({required this.onReserveTap});

  final VoidCallback onReserveTap;

  @override
  Widget build(BuildContext context) {
    return _PromoSurface(
      height: 530,
      background: Image.asset(
        'assets/images/barber_background.jpg',
        fit: BoxFit.cover,
      ),
      overlay: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x33000000),
          Color(0x8A000000),
          Color(0xCF000000),
        ],
        stops: [0.0, 0.52, 1.0],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardPill(
              icon: Icons.circle,
              text: 'MARDI · 9H - 13H',
            ),
            const Spacer(),
            const Text(
              'BARBE\nOFFERTE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 46,
                height: 0.94,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'avec ta coupe homme, chaque mardi matin\nau salon de Grenoble.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '30€',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white.withValues(alpha: 0.38),
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.white.withValues(alpha: 0.28),
                    decorationThickness: 2,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.26),
                ),
                const SizedBox(width: 14),
                const Text(
                  '20€',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _GlassButton(
              label: 'RÉSERVER MON MARDI',
              icon: Icons.arrow_forward_rounded,
              onTap: onReserveTap,
            ),
            const Spacer(),
            const Text(
              'SALON GRENOBLE · CENTRE-VILLE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: Color(0x66FFFFFF),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Valable uniquement sur réservation en ligne d\'une prestation Coupe + Barbe, le mardi de 9h à 13h.\n'
              'Les forfaits Coupe ne peuvent pas être transformés en Coupe + Barbe sur place.\n'
              'Non cumulable avec d\'autres offres.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingTeaserCard extends StatelessWidget {
  const _UpcomingTeaserCard({
    required this.revealAt,
    required this.onAlertTap,
  });

  final DateTime revealAt;
  final VoidCallback onAlertTap;

  @override
  Widget build(BuildContext context) {
    return _PromoSurface(
      height: 550,
      background: Image.asset(
        'assets/images/barber_background.jpg',
        fit: BoxFit.cover,
      ),
      overlay: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x25000000),
          Color(0x96000000),
          Color(0xE3000000),
        ],
        stops: [0.0, 0.58, 1.0],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardPill(
              icon: Icons.star_rounded,
              text: 'ÉVÉNEMENT',
            ),
            const Spacer(),
            const Center(
              child: Text(
                '2',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 110,
                  height: 0.92,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2.0,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 2),
            const Center(
              child: Text(
                'ANS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 24,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.28,
                  color: Color(0xCCFFFFFF),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'QUELQUE CHOSE SE PRÉPARE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 13,
                height: 1.1,
                fontWeight: FontWeight.w700,
                letterSpacing: 4.0,
                color: Color(0x70FFFFFF),
              ),
            ),
            const SizedBox(height: 22),
            _CountdownGrid(target: revealAt),
            const SizedBox(height: 24),
            _GlassButton(
              label: 'ÊTRE ALERTÉ',
              icon: Icons.notifications_none_rounded,
              onTap: onAlertTap,
            ),
            const SizedBox(height: 12),
            const Text(
              'DÉTAILS RÉVÉLÉS BIENTÔT',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
                color: Color(0x55FFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownGrid extends StatefulWidget {
  const _CountdownGrid({required this.target});

  final DateTime target;

  @override
  State<_CountdownGrid> createState() => _CountdownGridState();
}

class _CountdownGridState extends State<_CountdownGrid> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  Duration _computeRemaining() {
    final diff = widget.target.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _updateRemaining() {
    final next = _computeRemaining();
    if (mounted) {
      setState(() {
        _remaining = next;
      });
    } else {
      _remaining = next;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CountdownUnit(value: days.toString().padLeft(2, '0'), label: 'JOURS'),
          const _CountdownSeparator(),
          _CountdownUnit(value: hours.toString().padLeft(2, '0'), label: 'HEURES'),
          const _CountdownSeparator(),
          _CountdownUnit(value: minutes.toString().padLeft(2, '0'), label: 'MIN'),
          const _CountdownSeparator(),
          _CountdownUnit(value: seconds.toString().padLeft(2, '0'), label: 'SEC'),
        ],
      ),
    );
  }
}

class _CountdownSeparator extends StatelessWidget {
  const _CountdownSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ':',
        style: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  const _CountdownUnit({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.6),
                      radius: 1.0,
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: Colors.white.withValues(alpha: 0.22),
          ),
        ),
      ],
    );
  }
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PromoSurface(
      height: 210,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Stack(
          children: [
            Positioned(
              top: 2,
              left: 0,
              child: Text(
                'BARBERCLUB',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4.0,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CARTE CADEAU',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.3,
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Offrez l\'expérience',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 24,
                      height: 1.02,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.08,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Dès 20€',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: Color(0xB3FFFFFF),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Montant libre, valable 1 an dans nos deux salons.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.34),
                    ),
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

class _ConditionsSection extends StatelessWidget {
  const _ConditionsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel(text: 'CONDITIONS'),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Column(
            children: [
              _ConditionRow(
                icon: Icons.close_rounded,
                text: "Non cumulable avec d'autres offres",
              ),
              _ConditionRow(
                icon: Icons.calendar_month_rounded,
                text: 'Valable sur réservation en ligne',
              ),
              _ConditionRow(
                icon: Icons.info_outline_rounded,
                text: '1 offre maximum par réservation',
              ),
              _ConditionRow(
                icon: Icons.schedule_rounded,
                text: 'Offres limitées dans le temps',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoSurface extends StatelessWidget {
  const _PromoSurface({
    required this.height,
    required this.child,
    this.background,
    this.overlay,
    this.onTap,
  });

  final double height;
  final Widget child;
  final Widget? background;
  final Gradient? overlay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        color: const Color(0xFF090909),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (background != null) Positioned.fill(child: background!),
          if (overlay != null)
            Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: overlay)),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.02),
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.01),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.05,
                  colors: [
                    Colors.white.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _CardPill extends StatelessWidget {
  const _CardPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 7,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
                color: Colors.white.withValues(alpha: 0.78),
              ),
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
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBubbleButton extends StatelessWidget {
  const _IconBubbleButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}
