import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/loyalty_v2_state.dart';
import '../constants/loyalty_ui_constants.dart';
import '../providers/auth_providers.dart';
import '../providers/loyalty_providers.dart';

class PrivateClubLoyaltyView extends ConsumerWidget {
  const PrivateClubLoyaltyView({
    required this.state,
    this.previewRankKey,
    this.onPreviewRankChanged,
    super.key,
  });

  final LoyaltyV2State state;
  final String? previewRankKey;
  final ValueChanged<String>? onPreviewRankChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion =
        MediaQuery.of(context).disableAnimations ||
        MediaQuery.of(context).accessibleNavigation;
    final actualRankKey = _rankKeyFromName(
      state.rank.isNotEmpty ? state.rank : state.tier,
    );
    final visualRankKey = previewRankKey != null && kDebugMode
        ? previewRankKey!
        : actualRankKey;
    final palette = previewRankKey != null && kDebugMode
        ? _paletteForRankKey(visualRankKey)
        : _paletteFromState(state, actualRankKey);
    final visualAppointments = previewRankKey != null && kDebugMode
        ? _previewAppointmentsForKey(visualRankKey)
        : state.lifetimeAppointments;

    final nextKey = previewRankKey != null && kDebugMode
        ? _nextRankKey(visualRankKey)
        : (state.nextRank != null
              ? _rankKeyFromName(state.nextRank!.name)
              : _nextRankKey(actualRankKey));

    final currentRequirement = _rankRequirementForKey(visualRankKey);
    final nextRequirement = nextKey != null
        ? _rankRequirementForKey(nextKey)
        : null;
    final span = nextRequirement != null
        ? math.max(1, nextRequirement - currentRequirement)
        : 1;
    final rankProgress = nextRequirement != null
        ? ((visualAppointments - currentRequirement) / span)
              .clamp(0.0, 1.0)
              .toDouble()
        : 1.0;
    final nextRankLabel = nextKey != null ? _rankLabelFr(nextKey) : null;
    final currentRankLabel = _rankLabelFr(visualRankKey);
    final List<_VisualRankStep> visualRankScale = state.rankScale.isNotEmpty
        ? state.rankScale
              .map(
                (step) => _VisualRankStep(
                  key: _rankKeyFromName(step.name),
                  label: _rankLabelFr(_rankKeyFromName(step.name)),
                  requiredAppointments: step.requiredAppointments,
                  theme: _paletteFromRankTheme(step.theme),
                  isCurrent: _rankKeyFromName(step.name) == visualRankKey,
                  isReached: visualAppointments >= step.requiredAppointments,
                  remainingAppointments: math.max(
                    0,
                    step.requiredAppointments - visualAppointments,
                  ),
                ),
              )
              .toList(growable: false)
        : _fallbackRankScale;
    final milestones = [...state.rewardMilestones]
      ..sort((a, b) => a.costPoints.compareTo(b.costPoints));
    final firstLockedIndex = milestones.indexWhere((m) => !m.isReached);
    final nextMilestone = firstLockedIndex >= 0
        ? milestones[firstLockedIndex]
        : null;
    final redeemableCount = milestones.where((m) => m.canRedeem).length;
    final member = state.member;
    final memberName = member?.fullName.isNotEmpty == true
        ? member!.fullName
        : 'Membre BarberClub';
    final memberCode = member?.memberCode.isNotEmpty == true
        ? member!.memberCode
        : 'BC-00000000';
    final memberSince = state.enrolledAt.isNotEmpty
        ? _memberSinceLabel(state.enrolledAt)
        : 'Membre depuis -';
    final balanceLabel = 'Vous · ${state.memberPosition?.points ?? state.currentBalance} PTS';
    final pointsRuleLabel = _pointsRuleLabel(state.pointsRule);

    return Stack(
      fit: StackFit.expand,
      children: [
        _PrivateClubBackdrop(palette: palette, reduceMotion: reduceMotion),
        SafeArea(
          top: true,
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              LoyaltyUIConstants.horizontalScreenPadding,
              16,
              LoyaltyUIConstants.horizontalScreenPadding,
              LoyaltyUIConstants.bottomNavPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Reveal(
                  delay: const Duration(milliseconds: 20),
                  reduceMotion: reduceMotion,
                  child: _Header(
                    state: state,
                    palette: palette,
                    visualRankLabel: currentRankLabel,
                  ),
                ),
                if (onPreviewRankChanged != null) ...[
                  const SizedBox(height: 12),
                  _Reveal(
                    delay: const Duration(milliseconds: 60),
                    reduceMotion: reduceMotion,
                    child: _RankSwitch(
                      currentKey: visualRankKey,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _Reveal(
                  delay: const Duration(milliseconds: 120),
                  reduceMotion: reduceMotion,
                  child: _HeroSection(
                    state: state,
                    palette: palette,
                    memberName: memberName,
                    memberCode: memberCode,
                    memberSince: memberSince,
                    currentRankLabel: currentRankLabel,
                    nextRankLabel: nextRankLabel,
                    nextRequirement: nextRequirement,
                    visualAppointments: visualAppointments,
                    progress: rankProgress,
                    balanceLabel: balanceLabel,
                    reduceMotion: reduceMotion,
                  ),
                ),
                const SizedBox(height: 34),
                _SectionHeading(
                  eyebrow: 'Progression',
                  title: 'Les rangs du Club',
                  palette: palette,
                  body: 'Touchez un rang pour prévisualiser son univers.',
                ),
                const SizedBox(height: 18),
                _Reveal(
                  delay: const Duration(milliseconds: 180),
                  reduceMotion: reduceMotion,
                  child: _RankLadder(palette: palette, steps: visualRankScale),
                ),
                const SizedBox(height: 34),
                _SectionHeading(
                  eyebrow: 'Boutique de points',
                  title: 'Votre parcours récompenses',
                  palette: palette,
                  body: 'Débloquez les paliers au fil de vos points.',
                ),
                const SizedBox(height: 18),
                _Reveal(
                  delay: const Duration(milliseconds: 260),
                  reduceMotion: reduceMotion,
                  child: _RewardTimelineSection(
                    state: state,
                    palette: palette,
                    balanceLabel: balanceLabel,
                    nextMilestone: nextMilestone,
                    redeemableCount: redeemableCount,
                    reduceMotion: reduceMotion,
                    onRedeem: (reward) => _confirmRedeem(context, ref, reward),
                  ),
                ),
                const SizedBox(height: 34),
                _Reveal(
                  delay: const Duration(milliseconds: 340),
                  reduceMotion: reduceMotion,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      final howSection = _HowSection(
                        palette: palette,
                        pointsRuleLabel: pointsRuleLabel,
                      );
                      final activitySection = _ActivityFeed(palette: palette);

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: howSection),
                            const SizedBox(width: 20),
                            Expanded(child: activitySection),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          howSection,
                          const SizedBox(height: 20),
                          activitySection,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRedeem(
    BuildContext context,
    WidgetRef ref,
    LoyaltyRewardMilestoneItem reward,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Text(
          'Confirmer l’échange',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Confirmer l’échange de ${reward.costPoints} points pour ${_rewardDisplayTitle(reward)} ?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final dio = ref.read(dioClientProvider).dio;
    try {
      await dio.post<Map<String, dynamic>>(
        '/api/v1/loyalty/rewards/redeem',
        data: {'rewardId': reward.id},
      );
      if (!context.mounted) return;
      ref.invalidate(loyaltyV2StateProvider);
      ref.invalidate(loyaltyRewardsProvider);
      ref.invalidate(loyaltyTransactionsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Récompense échangée')));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Échange impossible')));
      }
    }
  }
}

class _PrivateClubBackdrop extends StatelessWidget {
  const _PrivateClubBackdrop({
    required this.palette,
    required this.reduceMotion,
  });

  final _PrivateClubPalette palette;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: Colors.black),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF24160C).withValues(alpha: 0.14),
                  Colors.transparent,
                  const Color(0xFF040404).withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.44, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 180, sigmaY: 180),
              child: Stack(
                children: [
                  Positioned(
                    top: -440,
                    left: -380,
                    child: _GlowOrb(
                      size: 1040,
                      color: palette.accent.withValues(alpha: 0.055),
                      reduceMotion: reduceMotion,
                      offset: const Offset(0, 0),
                    ),
                  ),
                  Positioned(
                    top: -180,
                    right: -420,
                    child: _GlowOrb(
                      size: 980,
                      color: palette.accent2.withValues(alpha: 0.045),
                      reduceMotion: reduceMotion,
                      offset: const Offset(0, 0),
                    ),
                  ),
                  Positioned(
                    bottom: -460,
                    left: -360,
                    child: _GlowOrb(
                      size: 1040,
                      color: palette.accent.withValues(alpha: 0.04),
                      reduceMotion: reduceMotion,
                      offset: const Offset(0, 0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Opacity(
            opacity: 0.025,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    required this.reduceMotion,
    required this.offset,
  });

  final double size;
  final Color color;
  final bool reduceMotion;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final widget = Transform.scale(
          scaleX: 1.55,
      scaleY: 0.82,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.72),
              color.withValues(alpha: 0.16),
              Colors.transparent,
            ],
            stops: const [0.0, 0.36, 1.0],
          ),
        ),
      ),
    );

    return Transform.translate(
      offset: offset,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: reduceMotion ? 120 : 150,
          sigmaY: reduceMotion ? 120 : 150,
        ),
        child: widget,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.palette,
    required this.visualRankLabel,
  });

  final LoyaltyV2State state;
  final _PrivateClubPalette palette;
  final String visualRankLabel;

  @override
  Widget build(BuildContext context) {
    final member = state.member;
    final memberName = member?.fullName.isNotEmpty == true
        ? member!.fullName
        : 'Membre BarberClub';
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final memberChipRank = visualRankLabel;
    final avatarUrl = AppConfig.resolveImageUrl(member?.avatarUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/common/logo-blanc.png',
                    height: 28,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'assets/images/barber_club_full_logo.png',
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: 10),
                    Container(
                      width: 1,
                      height: 24,
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'CLUB PRIVÉ · FIDÉLITÉ',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            memberName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [palette.accent, palette.accent2],
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              memberChipRank,
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ClipOval(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: avatarUrl != null
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        Image.asset(
                                  'assets/images/common/photo-membre-placeholder.jpg',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                'assets/images/common/photo-membre-placeholder.jpg',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankSwitch extends StatelessWidget {
  const _RankSwitch({
    required this.currentKey,
  });

  final String currentKey;

  static const List<String> _keys = [
    'bronze',
    'argent',
    'or',
    'diamant',
    'platine',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < _keys.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                _RankSwitchPill(
                  label: _rankLabelFr(_keys[index]),
                  palette: _paletteForRankKey(_keys[index]),
                  isSelected: _keys[index] == currentKey,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RankSwitchPill extends StatelessWidget {
  const _RankSwitchPill({
    required this.label,
    required this.palette,
    required this.isSelected,
  });

  final String label;
  final _PrivateClubPalette palette;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? palette.accent.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isSelected
              ? palette.accent.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: palette.glow.withValues(alpha: 0.36),
                  blurRadius: 18,
                  spreadRadius: 0,
                ),
              ]
            : const [],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? palette.ink : palette.accent,
                  boxShadow: [
                    BoxShadow(
                      color: palette.glow.withValues(alpha: 0.7),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? palette.ink : Colors.white70,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          if (isSelected)
            Positioned(
              left: 6,
              top: -11,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: palette.glow.withValues(alpha: 0.18),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Text(
                  'ACTUEL',
                  style: TextStyle(
                    color: Colors.black87,
                    fontFamily: 'Orbitron',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.state,
    required this.palette,
    required this.memberName,
    required this.memberCode,
    required this.memberSince,
    required this.currentRankLabel,
    required this.nextRankLabel,
    required this.nextRequirement,
    required this.visualAppointments,
    required this.progress,
    required this.balanceLabel,
    required this.reduceMotion,
  });

  final LoyaltyV2State state;
  final _PrivateClubPalette palette;
  final String memberName;
  final String memberCode;
  final String memberSince;
  final String currentRankLabel;
  final String? nextRankLabel;
  final int? nextRequirement;
  final int visualAppointments;
  final double progress;
  final String balanceLabel;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        const cardGap = SizedBox(height: 20);
        final heroMain = _MembershipCard(
          state: state,
          palette: palette,
          memberName: memberName,
          memberCode: memberCode,
          memberSince: memberSince,
          currentRankLabel: currentRankLabel,
          balanceLabel: balanceLabel,
          reduceMotion: reduceMotion,
        );
        final heroGoal = _GoalPanel(
          palette: palette,
          currentRankLabel: currentRankLabel,
          nextRankLabel: nextRankLabel,
          nextRequirement: nextRequirement,
          visualAppointments: visualAppointments,
          progress: progress,
          reduceMotion: reduceMotion,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heroMain),
              const SizedBox(width: 20),
              Expanded(child: heroGoal),
            ],
          );
        }

        return Column(children: [heroMain, cardGap, heroGoal]);
      },
    );
  }
}

class _RankPill extends StatelessWidget {
  const _RankPill({required this.palette, required this.label});

  final _PrivateClubPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.accent, palette.accent2],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: palette.glow.withValues(alpha: 0.32),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: palette.ink,
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.state,
    required this.palette,
    required this.memberName,
    required this.memberCode,
    required this.memberSince,
    required this.currentRankLabel,
    required this.balanceLabel,
    required this.reduceMotion,
  });

  final LoyaltyV2State state;
  final _PrivateClubPalette palette;
  final String memberName;
  final String memberCode;
  final String memberSince;
  final String currentRankLabel;
  final String balanceLabel;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final displayName = memberName.toUpperCase();
    final displayCode = _formatMemberCode(memberCode);
    final card = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.03),
            Colors.white.withValues(alpha: 0.06),
          ],
          stops: const [0.0, 0.46, 1.0],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 42,
            spreadRadius: 0,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CARTE DE MEMBRE',
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Orbitron',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              _RankPill(palette: palette, label: 'Rang $currentRankLabel'),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: state.currentBalance.toDouble()),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 1300),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Text(
                    value.round().toString(),
                    style: TextStyle(
                      color: palette.accent,
                      fontFamily: 'Orbitron',
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      height: 0.92,
                      shadows: [
                        Shadow(
                          color: palette.glow.withValues(alpha: 0.55),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'POINTS',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Solde disponible ? 1 ? d?pens? = 1 point',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Orbitron',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$memberSince · N° $displayCode',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              Container(
                width: 42,
                height: 31,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [palette.accent, palette.accent2],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: _SvgIcon(
                    svg: _svgShield,
                    size: 14,
                    color: palette.ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return _AnimatedCardChrome(palette: palette, reduceMotion: reduceMotion, child: card);
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.padding,
    this.surfaceOpacity = 0.05,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double surfaceOpacity;

  @override
  Widget build(BuildContext context) {
    final surface = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: surfaceOpacity + 0.03),
        Colors.white.withValues(alpha: surfaceOpacity * 0.65),
        Colors.white.withValues(alpha: surfaceOpacity + 0.015),
      ],
      stops: const [0.0, 0.46, 1.0],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 38,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AnimatedCardChrome extends StatefulWidget {
  const _AnimatedCardChrome({
    required this.palette,
    required this.reduceMotion,
    required this.child,
  });

  final _PrivateClubPalette palette;
  final bool reduceMotion;
  final Widget child;

  @override
  State<_AnimatedCardChrome> createState() => _AnimatedCardChromeState();
}

class _AnimatedCardChromeState extends State<_AnimatedCardChrome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
    if (!widget.reduceMotion) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedCardChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion != oldWidget.reduceMotion) {
      if (widget.reduceMotion) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = widget.reduceMotion ? 0.0 : _controller.value;
        final spin = t * math.pi * 2;
        final offset = -0.55 + (t * 1.8);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: SweepGradient(
              startAngle: spin,
              endAngle: spin + math.pi * 2,
              colors: [
                Colors.transparent,
                widget.palette.accent.withValues(alpha: 0.95),
                Colors.transparent,
                widget.palette.accent2.withValues(alpha: 0.32),
                Colors.transparent,
              ],
              stops: const [0.0, 0.13, 0.44, 0.73, 1.0],
            ),
          ),
          padding: const EdgeInsets.all(1.4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.6),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Stack(
                children: [
                  child!,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: widget.reduceMotion ? 0 : 1,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            return Transform.translate(
                              offset: Offset(offset * width, 0),
                              child: FractionallySizedBox(
                                widthFactor: 0.55,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withValues(alpha: 0.16),
                                        Colors.white.withValues(alpha: 0.44),
                                        Colors.white.withValues(alpha: 0.16),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.36, 0.50, 0.64, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _GoalPanel extends StatelessWidget {
  const _GoalPanel({
    required this.palette,
    required this.currentRankLabel,
    required this.nextRankLabel,
    required this.nextRequirement,
    required this.visualAppointments,
    required this.progress,
    required this.reduceMotion,
  });

  final _PrivateClubPalette palette;
  final String currentRankLabel;
  final String? nextRankLabel;
  final int? nextRequirement;
  final int visualAppointments;
  final double progress;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final total = nextRequirement ?? visualAppointments;
    final remaining = nextRequirement == null
        ? 0
        : math.max(0, nextRequirement! - visualAppointments);
    final title = nextRankLabel == null
        ? 'Rang maximum'
        : 'Bientôt $nextRankLabel';
    final body = nextRankLabel == null
        ? 'Vous avez atteint le rang le plus élevé du Club. Merci de votre fidélité.'
        : 'Encore $remaining rendez-vous pour débloquer le rang $nextRankLabel et ses avantages exclusifs.';
    final objective = nextRequirement == null
        ? 'Rang maximum atteint'
        : 'Objectif : $nextRequirement RDV';

    return _GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RingGauge(
                palette: palette,
                current: visualAppointments,
                total: total,
                progress: progress,
                reduceMotion: reduceMotion,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SvgIcon(
                            svg: _svgStar,
                            size: 11,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            objective,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Orbitron',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'RDV à vie',
                  value: visualAppointments.toString(),
                  accent: palette.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Points cumulés',
                  value: stateCurrentBalance(context).toString(),
                  accent: palette.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Récomp. prêtes',
                  value: '${_readyRewardsCount(context)}',
                  accent: palette.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int stateCurrentBalance(BuildContext context) {
    final widget = context
        .findAncestorWidgetOfExactType<PrivateClubLoyaltyView>();
    return widget?.state.currentBalance ?? 0;
  }

  int _readyRewardsCount(BuildContext context) {
    final widget = context
        .findAncestorWidgetOfExactType<PrivateClubLoyaltyView>();
    return widget?.state.rewardMilestones
            .where((reward) => reward.canRedeem)
            .length ??
        0;
  }
}

class _RingGauge extends StatelessWidget {
  const _RingGauge({
    required this.palette,
    required this.current,
    required this.total,
    required this.progress,
    required this.reduceMotion,
  });

  final _PrivateClubPalette palette;
  final int current;
  final int total;
  final double progress;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      height: 138,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CustomPaint(
                painter: _RingGaugePainter(
                  progress: value,
                  trackColor: Colors.white.withValues(alpha: 0.10),
                  progressColor: palette.accent,
                ),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: current.toDouble()),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 1300),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    value.round().toString(),
                    style: TextStyle(
                      color: palette.accent,
                      fontFamily: 'Orbitron',
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: palette.glow.withValues(alpha: 0.45),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  total > 0 ? 'sur $total' : 'sur —',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontFamily: 'Orbitron',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'RENDEZ-VOUS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontFamily: 'Orbitron',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingGaugePainter extends CustomPainter {
  _RingGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    const startAngle = -math.pi / 2;
    final sweep = math.pi * 2 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w900,
              fontSize: 20,
              height: 1,
              shadows: [
                Shadow(color: accent.withValues(alpha: 0.25), blurRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 9.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankLadder extends StatelessWidget {
  const _RankLadder({required this.palette, required this.steps});

  final _PrivateClubPalette palette;
  final List<_VisualRankStep> steps;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 18),
      surfaceOpacity: 0.045,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            right: 8,
            top: 23,
            child: Container(
              height: 2,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _RankStepCard(
                    step: steps[i],
                    isLast: i == steps.length - 1,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RankStepCard extends StatelessWidget {
  const _RankStepCard({required this.step, required this.isLast});

  final _VisualRankStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [step.theme.accent, step.theme.accent2],
        ),
        boxShadow: [
          BoxShadow(
            color: step.theme.glow.withValues(
              alpha: step.isCurrent ? 0.55 : 0.18,
            ),
            blurRadius: step.isCurrent ? 24 : 12,
            spreadRadius: 0,
          ),
        ],
        border: step.isCurrent
            ? Border.all(color: step.theme.accent, width: 2)
            : null,
      ),
      child: Center(
        child: _SvgIcon(
          svg: _rankIconSvg(step.key),
          size: step.key == 'platine' ? 21 : 22,
          color: step.theme.ink,
        ),
      ),
    );

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            badge,
            if (step.isCurrent)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ACTUEL',
                    style: TextStyle(
                      color: Colors.black87,
                      fontFamily: 'Orbitron',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 14,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              step.label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: step.isCurrent ? step.theme.accent : Colors.white70,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w700,
                fontSize: 9.2,
                letterSpacing: 0.9,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 12,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _rankRequirementLabel(step.requiredAppointments, step.key),
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 8.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RewardTimelineSection extends StatelessWidget {
  const _RewardTimelineSection({
    required this.state,
    required this.palette,
    required this.balanceLabel,
    required this.nextMilestone,
    required this.redeemableCount,
    required this.reduceMotion,
    required this.onRedeem,
  });

  final LoyaltyV2State state;
  final _PrivateClubPalette palette;
  final String balanceLabel;
  final LoyaltyRewardMilestoneItem? nextMilestone;
  final int redeemableCount;
  final bool reduceMotion;
  final ValueChanged<LoyaltyRewardMilestoneItem> onRedeem;

  @override
  Widget build(BuildContext context) {
    final milestones = [...state.rewardMilestones]
      ..sort((a, b) => a.costPoints.compareTo(b.costPoints));
    final insertIndex = milestones.indexWhere((reward) => !reward.isReached);

    return _GlassPanel(
      padding: const EdgeInsets.all(22),
      surfaceOpacity: 0.045,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: state.currentBalance.toDouble()),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        value.round().toString(),
                        style: TextStyle(
                          color: palette.accent,
                          fontFamily: 'Orbitron',
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: palette.glow.withValues(alpha: 0.5),
                              blurRadius: 22,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'points',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.1,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nextMilestone == null
                      ? 'Tous les paliers d?bloqu?s'
                      : 'Prochain palier : ${nextMilestone!.costPoints} pts ? plus que ${nextMilestone!.pointsRemaining} pts',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 2,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  for (var index = 0; index < milestones.length; index++) ...[
                    if (index == insertIndex)
                      _YouMarker(label: balanceLabel, palette: palette),
                    _RewardTimelineItem(
                      reward: milestones[index],
                      palette: palette,
                      onRedeem: onRedeem,
                      railColor: milestones[index].isReached
                          ? palette.accent
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ],
                  if (insertIndex >= milestones.length)
                    _YouMarker(label: balanceLabel, palette: palette),
                ],
              ),
            ],
          ),
          if (milestones.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Aucune r?compense configur?e',
              style: GoogleFonts.inter(color: Colors.white54),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '$redeemableCount r?compense(s) pr?te(s) ? ?tre utilis?e(s)',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _RewardTimelineItem extends StatelessWidget {
  const _RewardTimelineItem({
    required this.reward,
    required this.palette,
    required this.onRedeem,
    required this.railColor,
  });

  final LoyaltyRewardMilestoneItem reward;
  final _PrivateClubPalette palette;
  final ValueChanged<LoyaltyRewardMilestoneItem> onRedeem;
  final Color railColor;

  @override
  Widget build(BuildContext context) {
    final unlocked = reward.isReached;
    final nodeColor = unlocked ? palette.accent : const Color(0xFF202020);
    final iconColor = unlocked ? palette.ink : Colors.white54;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 54,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 26,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: railColor),
                  ),
                  Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: nodeColor,
                        border: Border.all(
                          color: unlocked
                              ? Colors.transparent
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                        boxShadow: unlocked
                            ? [
                                BoxShadow(
                                  color: palette.glow.withValues(alpha: 0.35),
                                  blurRadius: 18,
                                ),
                              ]
                            : const [],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: _SvgIcon(
                              svg: _rewardIconSvg(
                                reward.slug,
                                reward.costPoints,
                              ),
                              size: 22,
                              color: iconColor,
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 21,
                              height: 21,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: unlocked
                                    ? palette.accent
                                    : const Color(0xFF1C1C1C),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: _SvgIcon(
                                  svg: unlocked ? _svgCheck : _svgLock,
                                  size: unlocked ? 10 : 9,
                                  color: unlocked
                                      ? palette.ink
                                      : Colors.white54,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: unlocked
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${reward.costPoints} points',
                            style: TextStyle(
                              color: palette.accent,
                              fontFamily: 'Orbitron',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _rewardDisplayTitle(reward),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Orbitron',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _rewardDisplayDescription(reward),
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (unlocked)
                      FilledButton(
                        onPressed: reward.canRedeem
                            ? () => onRedeem(reward)
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accent,
                          foregroundColor: palette.ink,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Orbitron',
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 1.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('UTILISER'),
                      )
                    else
                      Text(
                        'Encore ${reward.pointsRemaining} pts',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 11.5,
                          height: 1.2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YouMarker extends StatelessWidget {
  const _YouMarker({required this.label, required this.palette});

  final String label;
  final _PrivateClubPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 34,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 54,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 17,
                    top: 8,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: palette.glow.withValues(alpha: 0.45),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowSection extends StatelessWidget {
  const _HowSection({required this.palette, required this.pointsRuleLabel});

  final _PrivateClubPalette palette;
  final String pointsRuleLabel;

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        '1',
        'Vous consommez',
        'Coupe, barbe, soins, produits - chaque euro cr?dite 1 point.',
      ),
      (
        '2',
        'Vous montez en rang',
        'Chaque RDV vous fait progresser de Bronze jusqu?? Platine.',
      ),
      (
        '3',
        'Vous ?changez',
        'Transformez vos points en remises et prestations offertes.',
      ),
    ];

    return _GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LE PRINCIPE',
            style: TextStyle(
              color: palette.accent,
              fontFamily: 'Orbitron',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            pointsRuleLabel.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 22),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      item.$1,
                      style: TextStyle(
                        color: palette.accent,
                        fontFamily: 'Orbitron',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$3,
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
          ],
        ],
      ),
    );
  }
}

class _ActivityFeed extends ConsumerWidget {
  const _ActivityFeed({required this.palette});

  final _PrivateClubPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loyaltyTransactionsProvider);
    return async.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return _emptyFeed();
        }
        return _GlassPanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ACTIVIT? DES POINTS',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.06,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < transactions.length && i < 4; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                _TransactionRow(transaction: transactions[i], palette: palette),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => _emptyFeed(),
    );
  }

  Widget _emptyFeed() {
    return _GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ACTIVIT? DES POINTS',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.06,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aucune op?ration r?cente',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction, required this.palette});

  final LoyaltyTransactionItem transaction;
  final _PrivateClubPalette palette;

  @override
  Widget build(BuildContext context) {
    final earned = transaction.points >= 0;
    final iconSvg = earned ? _svgArrowUpRight : _svgGiftBox;
    final iconColor = earned ? palette.accent : Colors.white54;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Center(
            child: _SvgIcon(svg: iconSvg, size: 18, color: iconColor),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatShortDate(transaction.createdAt),
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 11.5),
              ),
            ],
          ),
        ),
        Text(
          '${earned ? '+' : ''}${transaction.points} pts',
          style: TextStyle(
            color: earned ? palette.accent : Colors.white54,
            fontFamily: 'Orbitron',
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.palette,
    required this.body,
  });

  final String eyebrow;
  final String title;
  final _PrivateClubPalette palette;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: palette.accent,
            fontFamily: 'Orbitron',
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Orbitron',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.child,
    required this.delay,
    required this.reduceMotion,
  });

  final Widget child;
  final Duration delay;
  final bool reduceMotion;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _shown = true;
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        setState(() {
          _shown = true;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _Reveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion && !_shown) {
      _shown = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: widget.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 420),
      opacity: _shown ? 1 : 0,
      child: AnimatedSlide(
        duration: widget.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 420),
        offset: _shown ? Offset.zero : const Offset(0, 0.05),
        child: widget.child,
      ),
    );
  }
}

class _SvgIcon extends StatelessWidget {
  const _SvgIcon({required this.svg, required this.size, required this.color});

  final String svg;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      fit: BoxFit.contain,
    );
  }
}

class _PrivateClubPalette {
  const _PrivateClubPalette({
    required this.accent,
    required this.accent2,
    required this.glow,
    required this.ink,
  });

  final Color accent;
  final Color accent2;
  final Color glow;
  final Color ink;
}

class _VisualRankStep {
  const _VisualRankStep({
    required this.key,
    required this.label,
    required this.requiredAppointments,
    required this.theme,
    required this.isCurrent,
    required this.isReached,
    required this.remainingAppointments,
  });

  final String key;
  final String label;
  final int requiredAppointments;
  final _PrivateClubPalette theme;
  final bool isCurrent;
  final bool isReached;
  final int remainingAppointments;
}

const Map<String, _PrivateClubPalette> _rankPalettes = {
  'bronze': _PrivateClubPalette(
    accent: Color(0xFFE4975A),
    accent2: Color(0xFFC4753A),
    glow: Color(0xFFE4975A),
    ink: Color(0xFF2A1808),
  ),
  'argent': _PrivateClubPalette(
    accent: Color(0xFFBCC3CF),
    accent2: Color(0xFF7E8794),
    glow: Color(0xFFBCC3CF),
    ink: Color(0xFF191C23),
  ),
  'or': _PrivateClubPalette(
    accent: Color(0xFFF5C542),
    accent2: Color(0xFFE9A93A),
    glow: Color(0xFFF5C542),
    ink: Color(0xFF241A06),
  ),
  'diamant': _PrivateClubPalette(
    accent: Color(0xFF8FB4FF),
    accent2: Color(0xFFB98BFF),
    glow: Color(0xFF8FB4FF),
    ink: Color(0xFF0D1430),
  ),
  'platine': _PrivateClubPalette(
    accent: Color(0xFFDDF6EF),
    accent2: Color(0xFF84CFC8),
    glow: Color(0xFFDDF6EF),
    ink: Color(0xFF0E2321),
  ),
};

final List<_VisualRankStep> _fallbackRankScale = [
  _VisualRankStep(
    key: 'bronze',
    label: 'Bronze',
    requiredAppointments: 0,
    theme: _rankPalettes['bronze']!,
    isCurrent: false,
    isReached: true,
    remainingAppointments: 0,
  ),
  _VisualRankStep(
    key: 'argent',
    label: 'Argent',
    requiredAppointments: 10,
    theme: _rankPalettes['argent']!,
    isCurrent: false,
    isReached: false,
    remainingAppointments: 10,
  ),
  _VisualRankStep(
    key: 'or',
    label: 'Or',
    requiredAppointments: 20,
    theme: _rankPalettes['or']!,
    isCurrent: false,
    isReached: false,
    remainingAppointments: 20,
  ),
  _VisualRankStep(
    key: 'diamant',
    label: 'Diamant',
    requiredAppointments: 30,
    theme: _rankPalettes['diamant']!,
    isCurrent: false,
    isReached: false,
    remainingAppointments: 30,
  ),
  _VisualRankStep(
    key: 'platine',
    label: 'Platine',
    requiredAppointments: 50,
    theme: _rankPalettes['platine']!,
    isCurrent: false,
    isReached: false,
    remainingAppointments: 50,
  ),
];

String _rankKeyFromName(String rank) {
  switch (rank.trim().toLowerCase()) {
    case 'bronze':
      return 'bronze';
    case 'silver':
      return 'argent';
    case 'gold':
      return 'or';
    case 'diamond':
      return 'diamant';
    case 'platinum':
      return 'platine';
    case 'argent':
      return 'argent';
    case 'or':
      return 'or';
    case 'diamant':
      return 'diamant';
    case 'platine':
      return 'platine';
    default:
      return 'bronze';
  }
}

String _rankLabelFr(String key) {
  switch (key) {
    case 'argent':
      return 'Argent';
    case 'or':
      return 'Or';
    case 'diamant':
      return 'Diamant';
    case 'platine':
      return 'Platine';
    default:
      return 'Bronze';
  }
}

String? _nextRankKey(String key) {
  switch (key) {
    case 'bronze':
      return 'argent';
    case 'argent':
      return 'or';
    case 'or':
      return 'diamant';
    case 'diamant':
      return 'platine';
    default:
      return null;
  }
}

int _rankRequirementForKey(String key) {
  switch (key) {
    case 'argent':
      return 10;
    case 'or':
      return 20;
    case 'diamant':
      return 30;
    case 'platine':
      return 50;
    default:
      return 0;
  }
}

int _previewAppointmentsForKey(String key) {
  switch (key) {
    case 'bronze':
      return 4;
    case 'argent':
      return 12;
    case 'or':
      return 22;
    case 'diamant':
      return 34;
    case 'platine':
      return 57;
    default:
      return 4;
  }
}

_PrivateClubPalette _paletteForRankKey(String key) {
  return _rankPalettes[key] ?? _rankPalettes['bronze']!;
}

_PrivateClubPalette _paletteFromRankTheme(LoyaltyRankTheme theme) {
  return _PrivateClubPalette(
    accent: _parseCssColor(theme.accent, const Color(0xFFF5C542)),
    accent2: _parseCssColor(theme.accent2, const Color(0xFFE9A93A)),
    glow: _parseCssColor(theme.glow, const Color(0xFFF5C542)),
    ink: _parseCssColor(theme.ink, const Color(0xFF241A06)),
  );
}

_PrivateClubPalette _paletteFromState(LoyaltyV2State state, String key) {
  final theme = state.theme;
  if (theme != null) {
    return _paletteFromRankTheme(theme);
  }
  return _paletteForRankKey(key);
}

Color _parseCssColor(String? value, Color fallback) {
  final input = (value ?? '').trim();
  if (input.isEmpty) return fallback;
  if (input.startsWith('#')) {
    final hex = input.substring(1);
    if (hex.length == 3) {
      final expanded = hex.split('').map((c) => '$c$c').join();
      return Color(int.parse('FF$expanded', radix: 16));
    }
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
  }
  final rgba = RegExp(
    r'rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)',
  ).firstMatch(input);
  if (rgba != null) {
    final r = int.parse(rgba.group(1)!);
    final g = int.parse(rgba.group(2)!);
    final b = int.parse(rgba.group(3)!);
    final a = double.tryParse(rgba.group(4) ?? '1') ?? 1;
    return Color.fromRGBO(r, g, b, a);
  }
  return fallback;
}

String _formatMemberCode(String code) {
  final cleaned = code.trim();
  if (cleaned.isEmpty) return '----';
  return cleaned.startsWith('BC-') ? cleaned.substring(3) : cleaned;
}

String _memberSinceLabel(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) {
    return 'Membre depuis -';
  }
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  final month = months[date.month - 1];
  return 'Membre depuis ${date.day} $month ${date.year}';
}

String _pointsRuleLabel(LoyaltyPointsRule? rule) {
  final spend = rule?.spendAmount ?? 1;
  final points = rule?.pointsEarned ?? 1;
  final currency = rule?.spendCurrency == 'EUR'
      ? '€'
      : (rule?.spendCurrency ?? '€');
  return '$spend $currency = $points PT';
}

String _formatShortDate(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  const months = [
    'janv.',
    'fév.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _rewardDisplayTitle(LoyaltyRewardMilestoneItem reward) {
  switch (reward.slug) {
    case 'product_30_percent':
      return 'Produit -30 %';
    case 'free_product':
      return 'Produit offert';
    case 'fragrance_20_percent':
      return 'Parfum -20 %';
    case 'facial_or_beard_free':
      return 'Soin ou barbe offert';
    default:
      return reward.name;
  }
}

String _rewardDisplayDescription(LoyaltyRewardMilestoneItem reward) {
  switch (reward.slug) {
    case 'product_30_percent':
      return 'Sur un produit de la boutique';
    case 'free_product':
      return 'Un produit offert de la sélection Club';
    case 'fragrance_20_percent':
      return 'Sur un parfum de la maison';
    case 'facial_or_beard_free':
      return 'Soin du visage ou taille de barbe';
    default:
      return reward.description?.trim().isNotEmpty == true
          ? reward.description!.trim()
          : 'Récompense à débloquer';
  }
}

String _rankRequirementLabel(int requiredAppointments, String key) {
  if (key == 'bronze') {
    return 'Inscription';
  }
  return '$requiredAppointments RDV';
}

String _rewardIconSvg(String? slug, int costPoints) {
  switch (slug) {
    case 'product_30_percent':
      return _svgProductBag;
    case 'free_product':
      return _svgGiftBox;
    case 'fragrance_20_percent':
      return _svgFragrance;
    case 'facial_or_beard_free':
      return _svgBeard;
    default:
      if (costPoints >= 300) return _svgBeard;
      if (costPoints >= 250) return _svgFragrance;
      if (costPoints >= 150) return _svgGiftBox;
      return _svgProductBag;
  }
}

const String _svgShield = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="currentColor" d="M5 20h14v2H5v-2Zm14.2-13.5-3.7 2.2L12 3 8.5 8.7 4.8 6.5 3 18h18l-1.8-11.5Z"/>
</svg>
''';

const String _svgCheck = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="currentColor" d="m5 13 4 4L19 7"/>
</svg>
''';

const String _svgStar = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="currentColor" d="m12 2 2.4 7.4H22l-6 4.3 2.3 7.3-6.3-4.6-6.3 4.6L7.9 13.7 2 9.4h7.6L12 2Z"/>
</svg>
''';

const String _svgLock = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="none" stroke="currentColor" stroke-width="2.4" d="M8 11V8a4 4 0 0 1 8 0v3"/>
  <rect x="5" y="11" width="14" height="9" rx="2" fill="none" stroke="currentColor" stroke-width="2.4"/>
</svg>
''';

const String _svgProductBag = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="none" stroke="currentColor" stroke-width="1.8" d="M3 9h18l-1.5 10.5A2 2 0 0 1 17.5 21h-11A2 2 0 0 1 4.5 19.5L3 9Z"/>
  <path fill="none" stroke="currentColor" stroke-width="1.8" d="M8 9V6a4 4 0 0 1 8 0v3"/>
</svg>
''';

const String _svgGiftBox = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="none" stroke="currentColor" stroke-width="1.8" d="M20 12v9H4v-9M2 7h20v5H2zM12 22V7M12 7S10.5 3 8 3a2 2 0 0 0 0 4h4Zm0 0s1.5-4 4-4a2 2 0 0 1 0 4h-4Z"/>
</svg>
''';

const String _svgFragrance = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="none" stroke="currentColor" stroke-width="1.8" d="M9 2h6v3l2 2v3H7V7l2-2V2Z"/>
  <path fill="none" stroke="currentColor" stroke-width="1.8" d="M7 10h10v11a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V10Z"/>
</svg>
''';

const String _svgBeard = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="none" stroke="currentColor" stroke-width="1.8" d="M12 3c4 4 6 6 6 9a6 6 0 0 1-12 0c0-3 2-5 6-9Z"/>
</svg>
''';

const String _svgArrowUpRight = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="none" stroke="currentColor" stroke-width="1.8" d="M4 20 20 4M14 4h6v6"/>
</svg>
''';

String _rankIconSvg(String key) {
  switch (key) {
    case 'bronze':
    case 'argent':
    case 'or':
      return _svgShield;
    case 'diamant':
      return _svgDiamond;
    case 'platine':
      return _svgPlatinum;
    default:
      return _svgShield;
  }
}

const String _svgDiamond = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="currentColor" d="M6 3h12l4 6-10 12L2 9l4-6Z"/>
</svg>
''';

const String _svgPlatinum = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="currentColor" d="M12 2 4 7v10l8 5 8-5V7l-8-5Zm0 4.5L16 9v6l-4 2.5L8 15V9l4-2.5Z"/>
</svg>
''';
