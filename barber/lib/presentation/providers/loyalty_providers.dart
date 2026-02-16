import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/loyalty_card_data.dart';
import 'auth_providers.dart';

/// Optional callback to close the QR code dialog when a loyalty point is received via FCM.
/// Set when the QR dialog is shown, cleared when dialog closes or after FCM triggers close.
final qrDialogCloserProvider = StateProvider<void Function()?>((ref) => null);

/// Loyalty card data from GET /api/v1/loyalty/me (stamps = user.loyaltyPoints, target from config).
final loyaltyCardProvider = FutureProvider.autoDispose<LoyaltyCardData?>((ref) async {
  final authState = ref.watch(authStateProvider);

  if (authState.status != AuthStatus.authenticated || authState.user == null) {
    return null;
  }

  final user = authState.user!;
  final dio = ref.read(dioClientProvider).dio;

  final response = await dio.get('/api/v1/loyalty/me');
  final data = response.data as Map<String, dynamic>;
  final loyalty = data['data'] as Map<String, dynamic>? ?? {};
  final stamps = (loyalty['stamps'] as num?)?.toInt() ?? 0;
  final target = (loyalty['target'] as num?)?.toInt() ?? 10;
  final eligibleForReward = (loyalty['eligibleForReward'] as bool?) ?? (stamps >= target);

  final fullName = user.fullName ?? 'Membre';
  final parts = fullName.split(' ');
  final firstName = parts.isNotEmpty ? parts.first : 'Membre';
  final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

  final rewardLabel = eligibleForReward
      ? '1 coupe offerte – Débloquée'
      : 'Récompense : 1 coupe offerte (après $target visites)';

  return LoyaltyCardData(
    firstName: firstName,
    lastName: lastName,
    memberSince: DateTime.now().subtract(const Duration(days: 365)),
    currentVisits: stamps,
    totalRequiredVisits: target,
    rewardLabel: rewardLabel,
  );
});
