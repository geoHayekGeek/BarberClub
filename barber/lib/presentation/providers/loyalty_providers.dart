import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/loyalty_card_data.dart';
import 'auth_providers.dart';

final qrDialogCloserProvider = StateProvider<void Function()?>((ref) => null);

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
  final points = (loyalty['points'] as num?)?.toInt() ?? 0;
  final target = (loyalty['target'] as num?)?.toInt() ?? 10;
  final availableCoupons = (loyalty['availableCoupons'] as num?)?.toInt() ?? 0;

  final fullName = user.fullName ?? 'Membre';
  final parts = fullName.split(' ');
  final firstName = parts.isNotEmpty ? parts.first : 'Membre';
  final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

  final rewardLabel = availableCoupons > 0
      ? '$availableCoupons coupe${availableCoupons > 1 ? 's' : ''} offerte${availableCoupons > 1 ? 's' : ''} disponible${availableCoupons > 1 ? 's' : ''}'
      : 'Récompense : 1 coupe offerte (après $target visites)';

  return LoyaltyCardData(
    firstName: firstName,
    lastName: lastName,
    memberSince: DateTime.now().subtract(const Duration(days: 365)),
    currentVisits: points,
    totalRequiredVisits: target,
    rewardLabel: rewardLabel,
  );
});

final loyaltyCouponsProvider = FutureProvider.autoDispose<List<LoyaltyCoupon>>((ref) async {
  final authState = ref.watch(authStateProvider);

  if (authState.status != AuthStatus.authenticated) {
    return [];
  }

  final dio = ref.read(dioClientProvider).dio;
  final response = await dio.get('/api/v1/loyalty/coupons');
  final data = response.data as Map<String, dynamic>;
  final coupons = data['data'] as List<dynamic>? ?? [];

  return coupons.map((c) {
    final coupon = c as Map<String, dynamic>;
    return LoyaltyCoupon(
      id: coupon['id'] as String,
      createdAt: DateTime.parse(coupon['createdAt'] as String),
    );
  }).toList();
});

class LoyaltyCoupon {
  final String id;
  final DateTime createdAt;

  LoyaltyCoupon({required this.id, required this.createdAt});
}
