import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../constants/loyalty_ui_constants.dart';
import '../providers/auth_providers.dart';
import '../providers/loyalty_providers.dart';
import '../widgets/loyalty_card_widget.dart';

/// Carte Fidélité screen.
/// Shows loyalty card when authenticated; button to show QR for coiffeur to scan.
class LoyaltyCardScreen extends ConsumerWidget {
  const LoyaltyCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final loyaltyAsync = ref.watch(loyaltyCardProvider);

    final isAuthenticated = authState.status == AuthStatus.authenticated;

    return Scaffold(
      appBar: AppBar(
        title: const Text(LoyaltyStrings.pageTitle),
      ),
      body: SafeArea(
        child: isAuthenticated ? _buildCardContent(context, ref, loyaltyAsync) : _buildLoginPrompt(context),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Center(
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
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<dynamic> loyaltyAsync,
  ) {
    return loyaltyAsync.when(
      data: (data) {
        if (data == null) {
          return _buildLoginPrompt(context);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: LoyaltyUIConstants.sectionSpacing),
          child: Column(
            children: [
              LoyaltyCardWidget(data: data),
              const SizedBox(height: LoyaltyUIConstants.sectionSpacing),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: LoyaltyUIConstants.cardPadding),
                child: SizedBox(
                  width: double.infinity,
                  height: LoyaltyUIConstants.minTouchTargetSize,
                  child: FilledButton(
                    onPressed: () => _showQrCode(context, ref, data.currentVisits),
                    child: const Text('Afficher mon QR code'),
                  ),
                ),
              ),
              const SizedBox(height: LoyaltyUIConstants.sectionSpacing),
              _buildCouponsSection(context, ref),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => _buildLoginPrompt(context),
    );
  }

  Widget _buildCouponsSection(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(loyaltyCouponsProvider);

    return couponsAsync.when(
      data: (coupons) {
        if (coupons.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: LoyaltyUIConstants.cardPadding),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mes coupes offertes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                ...coupons.map((coupon) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showCouponQr(context, ref, coupon.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Utiliser cette coupe'),
                        ),
                      ),
                    )),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _showQrCode(BuildContext context, WidgetRef ref, int initialPoints) async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.post('/api/v1/loyalty/qr');
      final data = response.data as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>?;
      final qrPayload = payload?['qrPayload'] as String?;
      final expiresAt = payload?['expiresAt'] as String?;
      if (qrPayload == null || qrPayload.isEmpty) return;
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ctx.mounted) {
              ref.read(qrDialogCloserProvider.notifier).state = () => Navigator.of(ctx).pop();
            }
          });
          return _QrCodeDialog(
            qrPayload: qrPayload,
            expiresAt: expiresAt,
            initialPoints: initialPoints,
            dio: dio,
            onClosed: () {
              ref.read(qrDialogCloserProvider.notifier).state = null;
              ref.invalidate(loyaltyCardProvider);
            },
          );
        },
      );
      if (context.mounted) {
        ref.read(qrDialogCloserProvider.notifier).state = null;
        ref.invalidate(loyaltyCardProvider);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de générer le QR code')),
        );
      }
    }
  }

  Future<void> _showCouponQr(BuildContext context, WidgetRef ref, String couponId) async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.post('/api/v1/loyalty/coupons/$couponId/qr');
      final data = response.data as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>?;
      final qrPayload = payload?['qrPayload'] as String?;
      final expiresAt = payload?['expiresAt'] as String?;
      if (qrPayload == null || qrPayload.isEmpty) return;
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => _CouponQrDialog(
          qrPayload: qrPayload,
          expiresAt: expiresAt,
        ),
      );
      if (context.mounted) {
        ref.invalidate(loyaltyCouponsProvider);
        ref.invalidate(loyaltyCardProvider);
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

class _CouponQrDialog extends StatelessWidget {
  const _CouponQrDialog({
    required this.qrPayload,
    required this.expiresAt,
  });

  final String qrPayload;
  final String? expiresAt;

  @override
  Widget build(BuildContext context) {
    final expiryDate = expiresAt != null ? DateTime.tryParse(expiresAt!) : null;
    final isExpired = expiryDate != null && expiryDate.isBefore(DateTime.now());

    return AlertDialog(
      title: const Text('Coupe offerte'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 300,
            height: 300,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: QrImageView(
              data: qrPayload,
              version: QrVersions.auto,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              padding: const EdgeInsets.all(8),
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                color: Colors.black,
                dataModuleShape: QrDataModuleShape.square,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isExpired)
            Text(
              'QR code expiré',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.redAccent,
                  ),
              textAlign: TextAlign.center,
            )
          else
            Text(
              'À faire scanner pour valider votre coupe offerte',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
              textAlign: TextAlign.center,
            ),
          if (expiryDate != null && !isExpired)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Valable jusqu\'à ${_formatExpiry(expiryDate)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  String _formatExpiry(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _QrCodeDialog extends StatefulWidget {
  const _QrCodeDialog({
    required this.qrPayload,
    required this.expiresAt,
    required this.initialPoints,
    required this.dio,
    required this.onClosed,
  });

  final String qrPayload;
  final String? expiresAt;
  final int initialPoints;
  final Dio dio;
  final VoidCallback onClosed;

  @override
  State<_QrCodeDialog> createState() => _QrCodeDialogState();
}

class _QrCodeDialogState extends State<_QrCodeDialog> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkPoints());
  }

  Future<void> _checkPoints() async {
    try {
      final response = await widget.dio.get('/api/v1/loyalty/me');
      if (!mounted) return;
      final data = response.data as Map<String, dynamic>;
      final loyalty = data['data'] as Map<String, dynamic>? ?? {};
      final stamps = (loyalty['stamps'] as num?)?.toInt() ?? 0;
      if (stamps > widget.initialPoints) {
        _pollTimer?.cancel();
        _pollTimer = null;
        Navigator.of(context).pop();
        widget.onClosed();
      }
    } catch (_) {
      // ignore: poll again next time
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final expiresAt = widget.expiresAt != null ? DateTime.tryParse(widget.expiresAt!) : null;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());

    return AlertDialog(
      title: const Text('Mon QR code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 300,
            height: 300,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: QrImageView(
              data: widget.qrPayload,
              version: QrVersions.auto,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              padding: const EdgeInsets.all(8),
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                color: Colors.black,
                dataModuleShape: QrDataModuleShape.square,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isExpired)
            Text(
              'QR code expiré',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Colors.redAccent,
                  ),
              textAlign: TextAlign.center,
            )
          else
            Text(
              'Présentez ce QR code au coiffeur',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
              textAlign: TextAlign.center,
            ),
          if (expiresAt != null && !isExpired)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Valable jusqu\'à ${_formatExpiry(expiresAt)}',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  String _formatExpiry(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
