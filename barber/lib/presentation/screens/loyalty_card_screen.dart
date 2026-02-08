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
                    onPressed: () => _showQrCode(context, ref),
                    child: const Text('Afficher mon QR code'),
                  ),
                ),
              ),
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

  Future<void> _showQrCode(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.post('/api/v1/loyalty/qr');
      final data = response.data as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>?;
      final token = payload?['token'] as String?;
      if (token == null || token.isEmpty) return;
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          title: const Text('Mon QR code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 200,
                height: 200,
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  data: token,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
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
              Text(
                'À faire scanner par le coiffeur',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de générer le QR code')),
        );
      }
    }
  }
}
