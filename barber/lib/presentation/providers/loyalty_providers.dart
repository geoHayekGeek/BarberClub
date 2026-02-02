import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/loyalty_card_data.dart';
import 'auth_providers.dart';

/// Loyalty card data provider.
/// TODO: Replace with API call when backend is ready.
/// For now returns dummy data when user is authenticated.
final loyaltyCardProvider = FutureProvider.autoDispose<LoyaltyCardData?>((ref) async {
  final authState = ref.watch(authStateProvider);

  if (authState.status != AuthStatus.authenticated || authState.user == null) {
    return null;
  }

  // Simulate async fetch. Replace with: repository.getLoyaltyCard()
  await Future<void>.delayed(const Duration(milliseconds: 100));

  final user = authState.user!;
  final fullName = user.fullName ?? 'Membre';
  final parts = fullName.split(' ');
  final firstName = parts.isNotEmpty ? parts.first : 'Membre';
  final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

  return LoyaltyCardData(
    firstName: firstName,
    lastName: lastName,
    memberSince: DateTime.now().subtract(const Duration(days: 365)),
    currentVisits: 4,
    totalRequiredVisits: 10,
    rewardLabel: '1 coupe offerte',
  );
});
