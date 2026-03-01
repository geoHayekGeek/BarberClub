/// Loyalty v2: points-as-currency, tiers, rewards (from GET /loyalty/v2/me).
class LoyaltyV2State {
  final int currentBalance;
  final int lifetimeEarned;
  final String tier;
  final String enrolledAt;
  final LoyaltyNextTier? nextTier;

  const LoyaltyV2State({
    required this.currentBalance,
    required this.lifetimeEarned,
    required this.tier,
    required this.enrolledAt,
    this.nextTier,
  });

  static LoyaltyV2State fromJson(Map<String, dynamic> json) {
    final next = json['nextTier'] as Map<String, dynamic>?;
    return LoyaltyV2State(
      currentBalance: (json['currentBalance'] as num?)?.toInt() ?? 0,
      lifetimeEarned: (json['lifetimeEarned'] as num?)?.toInt() ?? 0,
      tier: json['tier'] as String? ?? 'Bronze',
      enrolledAt: json['enrolledAt'] as String? ?? '',
      nextTier: next != null
          ? LoyaltyNextTier(
              name: next['name'] as String? ?? '',
              remainingPoints: (next['remainingPoints'] as num?)?.toInt() ?? 0,
            )
          : null,
    );
  }
}

class LoyaltyNextTier {
  final String name;
  final int remainingPoints;

  const LoyaltyNextTier({required this.name, required this.remainingPoints});
}

/// Reward from GET /loyalty/rewards.
class LoyaltyRewardItem {
  final String id;
  final String name;
  final int costPoints;
  final String? description;
  final String? imageUrl;
  final bool isActive;

  const LoyaltyRewardItem({
    required this.id,
    required this.name,
    required this.costPoints,
    this.description,
    this.imageUrl,
    this.isActive = true,
  });

  static LoyaltyRewardItem fromJson(Map<String, dynamic> json) {
    return LoyaltyRewardItem(
      id: json['id'] as String,
      name: json['name'] as String,
      costPoints: (json['costPoints'] as num).toInt(),
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

/// Transaction from GET /loyalty/transactions.
class LoyaltyTransactionItem {
  final String id;
  final String type;
  final int points;
  final String description;
  final String createdAt;

  const LoyaltyTransactionItem({
    required this.id,
    required this.type,
    required this.points,
    required this.description,
    required this.createdAt,
  });

  static LoyaltyTransactionItem fromJson(Map<String, dynamic> json) {
    return LoyaltyTransactionItem(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      points: (json['points'] as num).toInt(),
      description: json['description'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

/// Redemption (voucher) from GET /loyalty/redemptions.
class LoyaltyRedemptionItem {
  final String id;
  final String rewardName;
  final int pointsSpent;
  final String status;
  final String redeemedAt;
  final String? usedAt;

  const LoyaltyRedemptionItem({
    required this.id,
    required this.rewardName,
    required this.pointsSpent,
    required this.status,
    required this.redeemedAt,
    this.usedAt,
  });

  static LoyaltyRedemptionItem fromJson(Map<String, dynamic> json) {
    return LoyaltyRedemptionItem(
      id: json['id'] as String,
      rewardName: json['rewardName'] as String? ?? '',
      pointsSpent: (json['pointsSpent'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'PENDING',
      redeemedAt: json['redeemedAt'] as String? ?? '',
      usedAt: json['usedAt'] as String?,
    );
  }

  bool get isPending => status == 'PENDING';
}
