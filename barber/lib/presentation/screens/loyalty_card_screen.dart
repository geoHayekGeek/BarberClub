import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/loyalty_ui_constants.dart';
import '../providers/auth_providers.dart';
import '../providers/loyalty_providers.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/loyalty_card_widget.dart';

/// Carte Fidélité screen.
/// Shows loyalty card when authenticated, login prompt otherwise.
///
/// TODO: QR code integration — display/scan UI will be added below the card
/// when backend provides QR payload. Do not implement QR logic until then.
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
        child: isAuthenticated ? _buildCardContent(context, loyaltyAsync) : _buildLoginPrompt(context),
      ),
      bottomNavigationBar: const BottomNavBar(),
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
    AsyncValue<dynamic> loyaltyAsync,
  ) {
    return loyaltyAsync.when(
      data: (data) {
        if (data == null) {
          return _buildLoginPrompt(context);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: LoyaltyUIConstants.sectionSpacing),
          child: LoyaltyCardWidget(data: data),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => _buildLoginPrompt(context),
    );
  }
}
