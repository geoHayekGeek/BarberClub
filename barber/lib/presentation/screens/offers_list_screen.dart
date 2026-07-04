import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/api_error.dart';
import '../../domain/models/website_offers_page_data.dart';
import '../providers/website_offers_providers.dart';

class OffersListScreen extends ConsumerStatefulWidget {
  const OffersListScreen({super.key});

  @override
  ConsumerState<OffersListScreen> createState() => _OffersListScreenState();
}

enum _OffersTab { current, upcoming }

class _OffersListScreenState extends ConsumerState<OffersListScreen> {
  void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go('/home');
  }

  WebsiteOffersPageData _fallbackPage(String salonSlug) {
    final normalizedSalonSlug = salonSlug.trim().toLowerCase();
    final pageUrl = Uri.parse(
      '${AppConfig.publicSiteBaseUrl}/pages/$normalizedSalonSlug/offres.html',
    );
    switch (normalizedSalonSlug) {
      case 'meylan':
        return WebsiteOffersPageData.fallbackMeylan(pageUrl);
      case 'grenoble':
      default:
        return WebsiteOffersPageData.fallbackGrenoble(pageUrl);
    }
  }

  List<WebsiteOffersPageData> _fallbackPages() {
    return [_fallbackPage('grenoble'), _fallbackPage('meylan')];
  }

  List<String> _mergedConditions(List<WebsiteOffersPageData> pages) {
    final merged = <String>[];
    final seen = <String>{};

    for (final page in pages) {
      for (final condition in page.conditions) {
        final normalized = condition.trim().toLowerCase();
        if (normalized.isEmpty || seen.contains(normalized)) continue;
        seen.add(normalized);
        merged.add(condition);
      }
    }

    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final offersAsync = ref.watch(websiteOffersPagesProvider);
    final pages = offersAsync.maybeWhen(
      data: (data) => data,
      orElse: _fallbackPages,
    );
    final sharedGiftCard = pages.first.giftCard;
    final sharedConditions = _mergedConditions(pages);

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
                      for (var index = 0; index < pages.length; index++) ...[
                        _SalonOffersBlock(
                          key: ValueKey(pages[index].salonId),
                          page: pages[index],
                          onReserveTap: () => context.go('/rdv'),
                        ),
                        if (index < pages.length - 1)
                          const SizedBox(height: 40),
                      ],
                      const SizedBox(height: 40),
                      _SharedOffersFooter(
                        giftCard: sharedGiftCard,
                        conditions: sharedConditions,
                        onGiftTap: () => context.go('/rdv'),
                      ),
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
                  colors: [Color(0x332D2812), Color(0x00000000)],
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
                  colors: [Color(0x26261E0B), Color(0x00000000)],
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
        _IconBubbleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
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
    required this.currentLabel,
    required this.upcomingLabel,
    required this.onChanged,
  });

  final _OffersTab selected;
  final String currentLabel;
  final String upcomingLabel;
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
              label: currentLabel,
              icon: Icons.circle,
              isActive: selected == _OffersTab.current,
              onTap: () => onChanged(_OffersTab.current),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _TabButton(
              label: upcomingLabel,
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
                    letterSpacing: 1.3,
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

class _SalonOffersBlock extends StatefulWidget {
  const _SalonOffersBlock({
    required this.page,
    required this.onReserveTap,
    super.key,
  });

  final WebsiteOffersPageData page;
  final VoidCallback onReserveTap;

  @override
  State<_SalonOffersBlock> createState() => _SalonOffersBlockState();
}

class _SalonOffersBlockState extends State<_SalonOffersBlock> {
  _OffersTab _selectedTab = _OffersTab.current;

  WebsiteOfferSection _selectedSection(WebsiteOffersPageData page) {
    final wantedType = switch (_selectedTab) {
      _OffersTab.current => WebsiteOfferSectionType.current,
      _OffersTab.upcoming => WebsiteOfferSectionType.upcoming,
    };

    for (final section in page.sections) {
      if (section.type == wantedType) {
        return section;
      }
    }

    return page.sections.first;
  }

  String _salonLabel(String salonId) {
    switch (salonId.trim().toLowerCase()) {
      case 'meylan':
        return 'BARBERCLUB MEYLAN';
      case 'grenoble':
        return 'BARBERCLUB GRENOBLE';
      default:
        return salonId.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final selectedSection = page.hasTabs
        ? _selectedSection(page)
        : page.sections.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(text: _salonLabel(page.salonId)),
        const SizedBox(height: 14),
        if (page.hasTabs) ...[
          _OffersTabSwitcher(
            selected: _selectedTab,
            currentLabel: page.currentTabLabel ?? 'Offre en cours',
            upcomingLabel: page.upcomingTabLabel ?? 'Offre à venir',
            onChanged: (tab) => setState(() => _selectedTab = tab),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: selectedSection.isCurrent
                ? _CurrentOffersSection(
                    key: const ValueKey('current'),
                    section: selectedSection,
                    onReserveTap: widget.onReserveTap,
                  )
                : _UpcomingOffersSection(
                    key: const ValueKey('upcoming'),
                    section: selectedSection,
                  ),
          ),
        ] else ...[
          _TeaserOffersSection(section: selectedSection),
        ],
      ],
    );
  }
}

class _CurrentOffersSection extends StatelessWidget {
  const _CurrentOffersSection({
    required this.section,
    required this.onReserveTap,
    super.key,
  });

  final WebsiteOfferSection section;
  final VoidCallback onReserveTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('current-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(text: section.sectionLabel.toUpperCase()),
        const SizedBox(height: 14),
        _CurrentPromoCard(section: section, onReserveTap: onReserveTap),
      ],
    );
  }
}

class _UpcomingOffersSection extends ConsumerStatefulWidget {
  const _UpcomingOffersSection({required this.section, super.key});

  final WebsiteOfferSection section;

  @override
  ConsumerState<_UpcomingOffersSection> createState() =>
      _UpcomingOffersSectionState();
}

class _UpcomingOffersSectionState
    extends ConsumerState<_UpcomingOffersSection> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _showForm = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitAlert() async {
    final config = widget.section.alertConfig;
    if (config == null) return;

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final message = await ref
          .read(websiteOffersRepositoryProvider)
          .subscribeToEventAlert(
            config: config,
            email: _emailController.text.trim(),
          );

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _showForm = false;
        _submitted = true;
        _errorMessage = null;
        _emailController.clear();
      });

      final bottomInset = MediaQuery.of(context).viewPadding.bottom;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            math.max(24.0, bottomInset + 92),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          backgroundColor: const Color(0xFF111111),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
          content: Text(
            message.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
      );
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'Impossible de contacter le site.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final config = section.alertConfig;

    return Column(
      key: const ValueKey('upcoming-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(text: section.sectionLabel.toUpperCase()),
        const SizedBox(height: 14),
        _PromoSurface(
          height: 550,
          background: _SectionBackground(
            imageUrl: section.imageUrl,
            fallbackAsset: 'assets/images/barber_background.jpg',
          ),
          overlay: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x25000000), Color(0x96000000), Color(0xE3000000)],
            stops: [0.0, 0.58, 1.0],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardPill(
                  icon: Icons.star_rounded,
                  text: section.badge ?? 'Événement',
                ),
                const Spacer(),
                Center(
                  child: Text(
                    section.headline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
                Center(
                  child: Text(
                    (section.subheadline ?? '').toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
                Text(
                  (section.description ?? '').toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 13,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4.0,
                    color: Color(0x70FFFFFF),
                  ),
                ),
                const SizedBox(height: 22),
                _CountdownGrid(
                  target: section.countdownTarget ?? DateTime.now(),
                ),
                const SizedBox(height: 22),
                if (config != null) ...[
                  if (_submitted)
                    _SuccessMessage(message: config.successMessage)
                  else if (_showForm)
                    _AlertForm(
                      formKey: _formKey,
                      controller: _emailController,
                      placeholder: config.emailPlaceholder,
                      isSubmitting: _submitting,
                      onSubmit: _submitAlert,
                      errorMessage: _errorMessage,
                    )
                  else
                    _GlassButton(
                      label: config.buttonLabel.toUpperCase(),
                      icon: Icons.notifications_none_rounded,
                      onTap: () => setState(() => _showForm = true),
                    ),
                ],
                const SizedBox(height: 12),
                Text(
                  section.details ?? 'Détails révélés bientôt',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                    color: Color(0x55FFFFFF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TeaserOffersSection extends StatelessWidget {
  const _TeaserOffersSection({required this.section});

  final WebsiteOfferSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('teaser-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_TeaserCard(section: section)],
    );
  }
}

class _SharedOffersFooter extends StatelessWidget {
  const _SharedOffersFooter({
    required this.giftCard,
    required this.conditions,
    required this.onGiftTap,
  });

  final WebsiteGiftCardData giftCard;
  final List<String> conditions;
  final VoidCallback onGiftTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(text: giftCard.sectionLabel.toUpperCase()),
        const SizedBox(height: 14),
        _GiftCard(giftCard: giftCard, onTap: onGiftTap),
        const SizedBox(height: 28),
        _ConditionsSection(conditions: conditions),
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
  const _CurrentPromoCard({required this.section, required this.onReserveTap});

  final WebsiteOfferSection section;
  final VoidCallback onReserveTap;

  @override
  Widget build(BuildContext context) {
    return _PromoSurface(
      height: 530,
      background: _SectionBackground(
        imageUrl: section.imageUrl,
        fallbackAsset: 'assets/images/barber_background.jpg',
      ),
      overlay: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x33000000), Color(0x8A000000), Color(0xCF000000)],
        stops: [0.0, 0.52, 1.0],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardPill(
              icon: Icons.circle,
              text: section.badge ?? 'Mardi · 9h – 13h',
            ),
            const Spacer(),
            Text(
              section.headline.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
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
              section.subheadline ?? '',
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
                  section.priceOld ?? '30€',
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
                Text(
                  section.priceNew ?? '20€',
                  style: const TextStyle(
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
              label: (section.ctaLabel ?? 'Réserver mon mardi').toUpperCase(),
              icon: Icons.arrow_forward_rounded,
              onTap: onReserveTap,
            ),
            const Spacer(),
            Text(
              (section.footnote ?? 'Salon Grenoble · centre-ville')
                  .toUpperCase(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.25,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    color: Color(0xAA000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              section.details ??
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

class _TeaserCard extends StatelessWidget {
  const _TeaserCard({required this.section});

  final WebsiteOfferSection section;

  @override
  Widget build(BuildContext context) {
    return _PromoSurface(
      height: 430,
      background: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x18000000), Color(0x90000000), Color(0xE8000000)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: _CardPill(icon: Icons.star_rounded, text: 'Événement'),
            ),
            const Spacer(),
            const Center(
              child: Icon(
                Icons.star_outline_rounded,
                size: 72,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              section.headline.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 28,
                height: 1.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.08,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              section.description ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ),
            const Spacer(),
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
          _CountdownUnit(
            value: days.toString().padLeft(2, '0'),
            label: 'Jours',
          ),
          const _CountdownSeparator(),
          _CountdownUnit(
            value: hours.toString().padLeft(2, '0'),
            label: 'Heures',
          ),
          const _CountdownSeparator(),
          _CountdownUnit(
            value: minutes.toString().padLeft(2, '0'),
            label: 'Min',
          ),
          const _CountdownSeparator(),
          _CountdownUnit(
            value: seconds.toString().padLeft(2, '0'),
            label: 'Sec',
          ),
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
  const _CountdownUnit({required this.value, required this.label});

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
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
          label.toUpperCase(),
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
  const _GiftCard({required this.giftCard, required this.onTap});

  final WebsiteGiftCardData giftCard;
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
                giftCard.watermark.toUpperCase(),
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
                    giftCard.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.3,
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    giftCard.title,
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 24,
                      height: 1.02,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.08,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    giftCard.price,
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: Color(0xB3FFFFFF),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    giftCard.description,
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
  const _ConditionsSection({required this.conditions});

  final List<String> conditions;

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
          child: Column(
            children: [
              for (var index = 0; index < conditions.length; index++)
                _ConditionRow(
                  icon: _conditionIconForIndex(index),
                  text: conditions[index],
                  showDivider: index != 0,
                ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _conditionIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.close_rounded;
      case 1:
        return Icons.calendar_month_rounded;
      case 2:
        return Icons.info_outline_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({
    required this.icon,
    required this.text,
    required this.showDivider,
  });

  final IconData icon;
  final String text;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: showDivider
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.transparent,
          ),
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

class _SectionBackground extends StatelessWidget {
  const _SectionBackground({required this.fallbackAsset, this.imageUrl});

  final String fallbackAsset;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(color: const Color(0xFF111111)),
        errorWidget: (context, error, stackTrace) =>
            Image.asset(fallbackAsset, fit: BoxFit.cover),
      );
    }

    return Image.asset(fallbackAsset, fit: BoxFit.cover);
  }
}

class _CardPill extends StatelessWidget {
  const _CardPill({required this.icon, required this.text});

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
            Icon(icon, size: 7, color: Colors.white.withValues(alpha: 0.9)),
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
  const _IconBubbleButton({required this.icon, required this.onTap});

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

class _AlertForm extends StatelessWidget {
  const _AlertForm({
    required this.formKey,
    required this.controller,
    required this.placeholder,
    required this.isSubmitting,
    required this.onSubmit,
    required this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final String placeholder;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Form(
          key: formKey,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              color: Colors.white.withValues(alpha: 0.03),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    enabled: !isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Veuillez entrer votre email';
                      }
                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!emailRegex.hasMatch(text)) {
                        return 'Email invalide';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => onSubmit(),
                    decoration: InputDecoration(
                      hintText: placeholder,
                      hintStyle: const TextStyle(
                        color: Color(0x4DFFFFFF),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: isSubmitting ? null : onSubmit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              size: 18,
                              color: Colors.black,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFD6A3A3),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _SuccessMessage extends StatelessWidget {
  const _SuccessMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              softWrap: true,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
