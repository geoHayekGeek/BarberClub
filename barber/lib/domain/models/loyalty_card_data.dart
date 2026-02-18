/// Loyalty card data. Built from /api/v1/loyalty/me + auth user.
class LoyaltyCardData {
  final String firstName;
  final String lastName;
  final DateTime memberSince;
  final int currentVisits;
  final int totalRequiredVisits;
  final String rewardLabel;

  const LoyaltyCardData({
    required this.firstName,
    required this.lastName,
    required this.memberSince,
    required this.currentVisits,
    required this.totalRequiredVisits,
    required this.rewardLabel,
  });

  String get fullName => '$firstName $lastName'.trim();
  int get memberYear => memberSince.year;

  /// Placeholder for future: LoyaltyCardData.fromJson(Map<String, dynamic> json)
  /// Backend will return something like:
  /// { "firstName", "lastName", "memberSince", "currentVisits", "totalRequiredVisits", "rewardLabel" }
}
