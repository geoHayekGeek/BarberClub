import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/network/dio_client.dart';
import '../../domain/models/loyalty_v2_state.dart';
import '../constants/loyalty_ui_constants.dart';
import '../providers/auth_providers.dart';
import '../providers/loyalty_providers.dart';
import '../widgets/app_primary_button.dart';

/// Loyalty v2 screen: points, tiers, rewards catalog, earn QR, vouchers, history.
/// UI matches mockups: no yellow, tier-specific accents, responsive layout.
class LoyaltyCardScreen extends ConsumerWidget {
  const LoyaltyCardScreen({super.key});

  static const double _horizontalPadding = LoyaltyUIConstants.horizontalScreenPadding;
  static const double _verticalRhythm = LoyaltyUIConstants.verticalRhythm;
  static const double _bottomNavPadding = LoyaltyUIConstants.bottomNavPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final stateAsync = ref.watch(loyaltyV2StateProvider);

    if (authState.status != AuthStatus.authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text(LoyaltyStrings.pageTitle)),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(LoyaltyUIConstants.cardPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    LoyaltyStrings.loginPrompt,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: LoyaltyUIConstants.sectionSpacing),
                  SizedBox(
                    height: LoyaltyUIConstants.minTouchTargetSize,
                    child: FilledButton(
                      onPressed: () => context.push('/login'),
                      child: const Text(LoyaltyStrings.loginButton),
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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          LoyaltyStrings.pageTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
      body: stateAsync.when(
        data: (state) {
          if (state == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _LoyaltyV2Body(state: state);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            'Erreur de chargement',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

class _LoyaltyV2Body extends ConsumerWidget {
  const _LoyaltyV2Body({required this.state});

  final LoyaltyV2State state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              LoyaltyCardScreen._horizontalPadding,
              LoyaltyCardScreen._verticalRhythm,
              LoyaltyCardScreen._horizontalPadding,
              LoyaltyCardScreen._bottomNavPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                SizedBox(height: LoyaltyUIConstants.betweenSections),
                _MainCard(state: state),
                SizedBox(height: LoyaltyUIConstants.betweenSections),
                _SectionTitle('VOTRE STATUT'),
                SizedBox(height: LoyaltyUIConstants.sectionTitleToContent),
                _TierCarousel(currentTier: state.tier),
                SizedBox(height: LoyaltyUIConstants.betweenSections),
                _SectionTitle('RÉCOMPENSES'),
                SizedBox(height: LoyaltyUIConstants.sectionTitleToContent),
                const _RewardsSection(),
                SizedBox(height: LoyaltyUIConstants.betweenSections),
                _SectionTitle('MES BONS'),
                SizedBox(height: LoyaltyUIConstants.sectionTitleToContent),
                const _RedemptionsSection(),
                SizedBox(height: LoyaltyUIConstants.betweenSections),
                _SectionTitle('HISTORIQUE RÉCENT'),
                SizedBox(height: LoyaltyUIConstants.sectionTitleToContent),
                const _TransactionsSection(),
                SizedBox(height: LoyaltyUIConstants.betweenSections),
                AppPrimaryButton(
                  label: 'Afficher mon QR',
                  onTap: () => _showEarnQr(context, ref),
                ),
                SizedBox(height: LoyaltyUIConstants.betweenSections),
                const _InfoCards(),
                SizedBox(height: LoyaltyUIConstants.betweenSections),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEarnQr(BuildContext context, WidgetRef ref) async {
    final dio = ref.read(dioClientProvider).dio;
    try {
      final response = await dio.post('/api/v1/loyalty/v2/qr');
      final data = response.data as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>?;
      final qrPayload = payload?['qrPayload'] as String?;
      final expiresAt = payload?['expiresAt'] as String?;
      if (qrPayload == null || qrPayload.isEmpty || !context.mounted) return;
      ref.read(qrDialogCloserProvider.notifier).state = () {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) Navigator.of(ctx).pop();
      };
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => _EarnQrFullscreenDialog(
          qrPayload: qrPayload,
          expiresAt: expiresAt,
          onClose: () => Navigator.of(ctx).pop(),
        ),
      );
      if (context.mounted) {
        ref.read(qrDialogCloserProvider.notifier).state = null;
        ref.invalidate(loyaltyV2StateProvider);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de générer le QR code')),
        );
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withOpacity(0.7),
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'BARBERCLUB',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'PROGRAMME FIDÉLITÉ',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white70,
                letterSpacing: 1,
              ),
        ),
      ],
    );
  }
}

class _MainCard extends StatelessWidget {
  const _MainCard({required this.state});

  final LoyaltyV2State state;

  static Color _tierColor(String tier) {
    switch (tier) {
      case 'Bronze':
        return const Color(0xFFCD7F32);
      case 'Silver':
        return const Color(0xFFC0C0C0);
      case 'Gold':
        return const Color(0xFFB8860B);
      case 'Platinum':
        return const Color(0xFFE5E4E2);
      default:
        return const Color(0xFFC0C0C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextTier = state.nextTier;
    final totalToNext = nextTier != null ? state.lifetimeEarned + nextTier.remainingPoints : 0.0;
    final progress = nextTier != null && nextTier.remainingPoints > 0 && totalToNext > 0
        ? 1.0 - (nextTier.remainingPoints / totalToNext)
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _tierColor(state.tier).withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _tierColor(state.tier).withOpacity(0.5)),
              ),
              child: Text(
                state.tier.toUpperCase(),
                style: TextStyle(
                  color: _tierColor(state.tier),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${state.currentBalance}',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 68,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'POINTS',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white54,
                  letterSpacing: 2,
                ),
          ),
          if (nextTier != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  state.tier,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${nextTier.name} — ${_nextTierThreshold(nextTier.name)} pts',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation<Color>(_tierColor(nextTier.name)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${nextTier.remainingPoints} pts avant ${nextTier.name}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static int _nextTierThreshold(String name) {
    switch (name) {
      case 'Silver': return 200;
      case 'Gold': return 500;
      case 'Platinum': return 1000;
      default: return 0;
    }
  }
}

class _TierCarousel extends StatelessWidget {
  const _TierCarousel({required this.currentTier});

  final String currentTier;

  static const List<String> _tiers = ['Bronze', 'Silver', 'Gold', 'Platinum'];

  static Color _tierColor(String t) {
    switch (t) {
      case 'Bronze': return const Color(0xFFCD7F32);
      case 'Silver': return const Color(0xFFC0C0C0);
      case 'Gold': return const Color(0xFFB8860B);
      case 'Platinum': return const Color(0xFFE5E4E2);
      default: return const Color(0xFFC0C0C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: LoyaltyUIConstants.tierCarouselHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _tiers.length,
        itemBuilder: (context, index) {
          final tier = _tiers[index];
          final isCurrent = tier == currentTier;
          return Container(
            width: LoyaltyUIConstants.tierCardWidth,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isCurrent ? _tierColor(tier).withOpacity(0.15) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrent ? _tierColor(tier) : Colors.white.withOpacity(0.08),
                width: isCurrent ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _tierIcon(tier),
                        size: 28,
                        color: isCurrent ? _tierColor(tier) : Colors.white.withOpacity(0.25),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tier.toUpperCase(),
                        style: TextStyle(
                          color: isCurrent ? _tierColor(tier) : Colors.white54,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _tierRange(tier),
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ACTUEL',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static IconData _tierIcon(String t) {
    switch (t) {
      case 'Bronze': return Icons.star_outline;
      case 'Silver': return Icons.star_outline;
      case 'Gold': return Icons.workspace_premium_outlined;
      case 'Platinum': return Icons.diamond_outlined;
      default: return Icons.star_outline;
    }
  }

  static String _tierRange(String t) {
    switch (t) {
      case 'Bronze': return '0 - 199 pts';
      case 'Silver': return '200 - 499 pts';
      case 'Gold': return '500 - 999 pts';
      case 'Platinum': return '1000+ pts';
      default: return '';
    }
  }
}

class _RewardsSection extends ConsumerWidget {
  const _RewardsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(loyaltyRewardsProvider);
    final stateAsync = ref.watch(loyaltyV2StateProvider);
    return rewardsAsync.when(
      data: (rewards) {
        if (rewards.isEmpty) {
          return Text(
            'Aucune récompense disponible',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54),
          );
        }
        final balance = stateAsync.valueOrNull?.currentBalance ?? 0;
        return SizedBox(
          height: LoyaltyUIConstants.rewardsListHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final r = rewards[index];
              final canAfford = balance >= r.costPoints;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: LoyaltyUIConstants.rewardCardWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 8),
                              ClipOval(
                                child: r.imageUrl != null && r.imageUrl!.isNotEmpty
                                    ? Image.network(
                                        AppConfig.resolveImageUrl(r.imageUrl) ?? r.imageUrl!,
                                        height: 80,
                                        width: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _rewardPlaceholder(),
                                      )
                                    : _rewardPlaceholder(),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${r.costPoints}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 28,
                                ),
                              ),
                              Text(
                                'pts',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                r.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: Material(
                                  color: canAfford ? Colors.white : Colors.white24,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    onTap: canAfford ? () => _confirmRedeem(context, ref, r) : null,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Center(
                                        child: Text(
                                          'Échanger',
                                          style: TextStyle(
                                            color: canAfford ? Colors.black87 : Colors.white54,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
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
              );
            },
          ),
        );
      },
      loading: () => SizedBox(height: LoyaltyUIConstants.rewardsListHeight, child: const Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  static Widget _rewardPlaceholder() {
    return Container(
      height: 80,
      width: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.card_giftcard, color: Colors.white.withOpacity(0.3), size: 36),
    );
  }

  Future<void> _confirmRedeem(BuildContext context, WidgetRef ref, LoyaltyRewardItem r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Échanger des points'),
        content: Text(
          'Utiliser ${r.costPoints} points pour "${r.name}" ?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final dio = ref.read(dioClientProvider).dio;
    try {
      await dio.post('/api/v1/loyalty/rewards/redeem', data: {'rewardId': r.id});
      if (context.mounted) {
        ref.invalidate(loyaltyV2StateProvider);
        ref.invalidate(loyaltyRewardsProvider);
        ref.invalidate(loyaltyRedemptionsProvider);
        ref.invalidate(loyaltyTransactionsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Récompense "${r.name}" échangée. Consultez "Mes bons".')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échange impossible')),
        );
      }
    }
  }
}

class _RedemptionsSection extends ConsumerWidget {
  const _RedemptionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loyaltyRedemptionsProvider);
    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return Text(
            'Aucun bon pour le moment',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: list.map((r) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    r.rewardName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      r.status == 'PENDING' ? 'À faire valider en salon' : 'Utilisé',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  trailing: r.isPending
                      ? TextButton(
                          onPressed: () => _showVoucherQr(context, ref, r.id),
                          child: const Text('Afficher QR'),
                        )
                      : null,
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _showVoucherQr(BuildContext context, WidgetRef ref, String redemptionId) async {
    final dio = ref.read(dioClientProvider).dio;
    try {
      final response = await dio.post('/api/v1/loyalty/redemptions/$redemptionId/qr');
      final data = response.data as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>?;
      final qrPayload = payload?['qrPayload'] as String?;
      if (qrPayload == null || qrPayload.isEmpty || !context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bon à valider'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Présentez ce QR au coiffeur pour valider votre bon',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer')),
          ],
        ),
      );
      if (context.mounted) ref.invalidate(loyaltyRedemptionsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de générer le QR')),
        );
      }
    }
  }
}

class _TransactionsSection extends ConsumerWidget {
  const _TransactionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loyaltyTransactionsProvider);
    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return Text(
            'Aucune opération récente',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < list.length && i < 10; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                  ),
                _TransactionRow(t: list[i]),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.t});

  final LoyaltyTransactionItem t;

  static String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = ['janv.', 'fév.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    final i = d.month - 1;
    return '${d.day} ${i >= 0 && i < months.length ? months[i] : ''} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isEarn = t.points > 0;
    return Row(
      children: [
        Icon(
          isEarn ? Icons.add_circle : Icons.remove_circle,
          color: isEarn ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.description,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(t.createdAt),
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          '${isEarn ? "+" : ""}${t.points} pts',
          style: TextStyle(
            color: isEarn ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _InfoCards extends StatelessWidget {
  const _InfoCards();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _InfoCard(
          icon: Icons.attach_money,
          text: '1 point par euro dépensé',
          boldPart: '1 point',
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.swap_horiz,
          text: 'Échangez vos points quand vous voulez',
          boldPart: 'quand vous voulez',
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.schedule,
          text: "Vos points n'expirent jamais",
          boldPart: "n'expirent jamais",
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.text,
    required this.boldPart,
  });

  final IconData icon;
  final String text;
  final String boldPart;

  @override
  Widget build(BuildContext context) {
    final idx = text.indexOf(boldPart);
    final before = idx >= 0 ? text.substring(0, idx) : text;
    final bold = idx >= 0 ? text.substring(idx, idx + boldPart.length) : '';
    final after = idx >= 0 && idx + boldPart.length <= text.length ? text.substring(idx + boldPart.length) : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                children: [
                  TextSpan(text: before),
                  TextSpan(
                    text: bold,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: after),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarnQrFullscreenDialog extends StatefulWidget {
  const _EarnQrFullscreenDialog({
    required this.qrPayload,
    required this.expiresAt,
    required this.onClose,
  });

  final String qrPayload;
  final String? expiresAt;
  final VoidCallback onClose;

  @override
  State<_EarnQrFullscreenDialog> createState() => _EarnQrFullscreenDialogState();
}

class _EarnQrFullscreenDialogState extends State<_EarnQrFullscreenDialog> {
  Timer? _timer;
  int _secondsLeft = 120;

  @override
  void initState() {
    super.initState();
    if (widget.expiresAt != null) {
      final end = DateTime.tryParse(widget.expiresAt!);
      if (end != null) {
        _updateSecondsLeft(end);
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateSecondsLeft(end));
      }
    }
  }

  void _updateSecondsLeft(DateTime end) {
    final left = end.difference(DateTime.now()).inSeconds;
    if (left <= 0 && _timer != null) {
      _timer?.cancel();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (mounted) setState(() => _secondsLeft = left > 0 ? left : 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF121212),
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: widget.onClose,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: QrImageView(
                data: widget.qrPayload,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
            const Spacer(),
            Text(
              'Présentez ce QR code au coiffeur',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
            ),
            if (_secondsLeft > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Expire dans ${_secondsLeft}s',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
