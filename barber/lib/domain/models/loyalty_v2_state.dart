/// Loyalty v2: points-as-currency, appointment ranks, rewards.
class LoyaltyV2State {
  final int currentBalance;
  final int lifetimeEarned;
  final int lifetimeAppointments;
  final String tier;
  final String rank;
  final String enrolledAt;
  final LoyaltyMember? member;
  final LoyaltyNextTier? nextTier;
  final LoyaltyNextRank? nextRank;
  final LoyaltyRankTheme? theme;
  final Map<String, String> themeVariables;
  final LoyaltyMemberPosition? memberPosition;
  final double rankProgress;
  final List<LoyaltyRankScaleItem> rankScale;
  final List<LoyaltyRewardMilestoneItem> rewardMilestones;
  final LoyaltyPointsRule? pointsRule;

  const LoyaltyV2State({
    required this.currentBalance,
    required this.lifetimeEarned,
    required this.lifetimeAppointments,
    required this.tier,
    required this.rank,
    required this.enrolledAt,
    this.member,
    this.nextTier,
    this.nextRank,
    this.theme,
    this.themeVariables = const {},
    this.memberPosition,
    this.rankProgress = 0,
    this.rankScale = const [],
    this.rewardMilestones = const [],
    this.pointsRule,
  });

  static LoyaltyV2State fromJson(Map<String, dynamic> json) {
    final next = json['nextTier'] as Map<String, dynamic>?;
    final nextRank = json['nextRank'] as Map<String, dynamic>?;
    final member = json['member'] as Map<String, dynamic>?;
    final theme = json['theme'] as Map<String, dynamic>?;
    final memberPosition = json['memberPosition'] as Map<String, dynamic>?;
    final themeVariables = json['themeVariables'] as Map<String, dynamic>?;
    final rankScale = json['rankScale'] as List<dynamic>? ?? const [];
    final rewardMilestones =
        json['rewardMilestones'] as List<dynamic>? ?? const [];
    final pointsRule = json['pointsRule'] as Map<String, dynamic>?;
    final tier = json['tier'] as String? ?? json['rank'] as String? ?? 'Bronze';

    return LoyaltyV2State(
      currentBalance: (json['currentBalance'] as num?)?.toInt() ?? 0,
      lifetimeEarned: (json['lifetimeEarned'] as num?)?.toInt() ?? 0,
      lifetimeAppointments:
          (json['lifetimeAppointments'] as num?)?.toInt() ?? 0,
      tier: tier,
      rank: json['rank'] as String? ?? tier,
      enrolledAt: json['enrolledAt'] as String? ?? '',
      member: member != null ? LoyaltyMember.fromJson(member) : null,
      nextTier: next != null
          ? LoyaltyNextTier(
              name: next['name'] as String? ?? '',
              remainingPoints: (next['remainingPoints'] as num?)?.toInt() ?? 0,
              requiredAppointments: (next['requiredAppointments'] as num?)
                  ?.toInt(),
              remainingAppointments: (next['remainingAppointments'] as num?)
                  ?.toInt(),
            )
          : null,
      nextRank: nextRank != null ? LoyaltyNextRank.fromJson(nextRank) : null,
      theme: theme != null ? LoyaltyRankTheme.fromJson(theme) : null,
      themeVariables: themeVariables != null
          ? themeVariables.map(
              (key, value) => MapEntry(key, value?.toString() ?? ''),
            )
          : const {},
      memberPosition: memberPosition != null
          ? LoyaltyMemberPosition.fromJson(memberPosition)
          : null,
      rankProgress: (json['rankProgress'] as num?)?.toDouble() ?? 0,
      rankScale: rankScale
          .map(
            (item) =>
                LoyaltyRankScaleItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      rewardMilestones: rewardMilestones
          .map(
            (item) => LoyaltyRewardMilestoneItem.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      pointsRule: pointsRule != null
          ? LoyaltyPointsRule.fromJson(pointsRule)
          : null,
    );
  }
}

class LoyaltyMember {
  final String id;
  final String memberCode;
  final String fullName;
  final String? avatarUrl;

  const LoyaltyMember({
    required this.id,
    required this.memberCode,
    required this.fullName,
    this.avatarUrl,
  });

  static LoyaltyMember fromJson(Map<String, dynamic> json) {
    return LoyaltyMember(
      id: json['id'] as String? ?? '',
      memberCode: json['memberCode'] as String? ?? '',
      fullName: json['fullName'] as String? ?? 'Member',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class LoyaltyMemberPosition {
  final String label;
  final int points;

  const LoyaltyMemberPosition({required this.label, required this.points});

  static LoyaltyMemberPosition fromJson(Map<String, dynamic> json) {
    return LoyaltyMemberPosition(
      label: json['label'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}

class LoyaltyNextTier {
  final String name;
  final int remainingPoints;
  final int? requiredAppointments;
  final int? remainingAppointments;

  const LoyaltyNextTier({
    required this.name,
    required this.remainingPoints,
    this.requiredAppointments,
    this.remainingAppointments,
  });
}

class LoyaltyNextRank {
  final String name;
  final int requiredAppointments;
  final int remainingAppointments;

  const LoyaltyNextRank({
    required this.name,
    required this.requiredAppointments,
    required this.remainingAppointments,
  });

  static LoyaltyNextRank fromJson(Map<String, dynamic> json) {
    return LoyaltyNextRank(
      name: json['name'] as String? ?? '',
      requiredAppointments:
          (json['requiredAppointments'] as num?)?.toInt() ?? 0,
      remainingAppointments:
          (json['remainingAppointments'] as num?)?.toInt() ?? 0,
    );
  }
}

class LoyaltyRankTheme {
  final String accent;
  final String accent2;
  final String glow;
  final String ink;

  const LoyaltyRankTheme({
    required this.accent,
    required this.accent2,
    required this.glow,
    required this.ink,
  });

  static LoyaltyRankTheme fromJson(Map<String, dynamic> json) {
    return LoyaltyRankTheme(
      accent: json['accent'] as String? ?? '#FFFFFF',
      accent2: json['accent2'] as String? ?? '#FFFFFF',
      glow: json['glow'] as String? ?? 'rgba(255,255,255,.35)',
      ink: json['ink'] as String? ?? '#000000',
    );
  }
}

class LoyaltyRankScaleItem {
  final String name;
  final int requiredAppointments;
  final LoyaltyRankTheme theme;
  final bool isCurrent;
  final bool isReached;
  final int remainingAppointments;

  const LoyaltyRankScaleItem({
    required this.name,
    required this.requiredAppointments,
    required this.theme,
    required this.isCurrent,
    required this.isReached,
    required this.remainingAppointments,
  });

  static LoyaltyRankScaleItem fromJson(Map<String, dynamic> json) {
    return LoyaltyRankScaleItem(
      name: json['name'] as String? ?? '',
      requiredAppointments:
          (json['requiredAppointments'] as num?)?.toInt() ?? 0,
      theme: LoyaltyRankTheme.fromJson(
        json['theme'] as Map<String, dynamic>? ?? const {},
      ),
      isCurrent: json['isCurrent'] as bool? ?? false,
      isReached: json['isReached'] as bool? ?? false,
      remainingAppointments:
          (json['remainingAppointments'] as num?)?.toInt() ?? 0,
    );
  }
}

class LoyaltyPointsRule {
  final int spendAmount;
  final String spendCurrency;
  final int pointsEarned;

  const LoyaltyPointsRule({
    required this.spendAmount,
    required this.spendCurrency,
    required this.pointsEarned,
  });

  static LoyaltyPointsRule fromJson(Map<String, dynamic> json) {
    return LoyaltyPointsRule(
      spendAmount: (json['spendAmount'] as num?)?.toInt() ?? 1,
      spendCurrency: json['spendCurrency'] as String? ?? 'EUR',
      pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Reward from GET /loyalty/rewards.
class LoyaltyRewardItem {
  final String id;
  final String? slug;
  final String name;
  final int costPoints;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final int sortOrder;

  const LoyaltyRewardItem({
    required this.id,
    required this.name,
    required this.costPoints,
    this.slug,
    this.description,
    this.imageUrl,
    this.isActive = true,
    this.sortOrder = 0,
  });

  static LoyaltyRewardItem fromJson(Map<String, dynamic> json) {
    return LoyaltyRewardItem(
      id: json['id'] as String,
      slug: json['slug'] as String?,
      name: json['name'] as String,
      costPoints: (json['costPoints'] as num).toInt(),
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class LoyaltyRewardMilestoneItem extends LoyaltyRewardItem {
  final bool isReached;
  final bool canRedeem;
  final bool isLocked;
  final int pointsRemaining;
  final String remainingLabel;
  final String positionLabel;

  const LoyaltyRewardMilestoneItem({
    required super.id,
    required super.name,
    required super.costPoints,
    required this.isReached,
    required this.canRedeem,
    required this.isLocked,
    required this.pointsRemaining,
    required this.remainingLabel,
    required this.positionLabel,
    super.slug,
    super.description,
    super.imageUrl,
    super.isActive,
    super.sortOrder,
  });

  static LoyaltyRewardMilestoneItem fromJson(Map<String, dynamic> json) {
    return LoyaltyRewardMilestoneItem(
      id: json['id'] as String,
      slug: json['slug'] as String?,
      name: json['name'] as String? ?? '',
      costPoints: (json['costPoints'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isReached: json['isReached'] as bool? ?? false,
      canRedeem: json['canRedeem'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? true,
      pointsRemaining: (json['pointsRemaining'] as num?)?.toInt() ?? 0,
      remainingLabel: json['remainingLabel'] as String? ?? '',
      positionLabel: json['positionLabel'] as String? ?? '',
    );
  }
}

/// Transaction from GET /loyalty/transactions.
class LoyaltyTransactionItem {
  final String id;
  final String type;
  final int points;
  final int appointmentCount;
  final String description;
  final String createdAt;

  const LoyaltyTransactionItem({
    required this.id,
    required this.type,
    required this.points,
    required this.description,
    required this.createdAt,
    this.appointmentCount = 0,
  });

  static LoyaltyTransactionItem fromJson(Map<String, dynamic> json) {
    return LoyaltyTransactionItem(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      points: (json['points'] as num).toInt(),
      appointmentCount: (json['appointmentCount'] as num?)?.toInt() ?? 0,
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
