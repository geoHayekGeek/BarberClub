/// UI constants and French strings for Carte Fidélité feature.
library;

/// Design tokens for loyalty card (no magic numbers in widgets).
class LoyaltyUIConstants {
  LoyaltyUIConstants._();

  // Card
  static const double cardWidthFraction = 0.9;
  static const double cardBorderRadius = 16;
  static const double cardPadding = 24;

  // Progress bar
  static const double segmentHeight = 8;
  static const double segmentSpacing = 4;
  static const double segmentMinWidth = 20;

  // Spacing
  static const double sectionSpacing = 20;
  static const double textSpacing = 8;
  static const double horizontalScreenPadding = 20;
  static const double verticalRhythm = 16;
  static const double sectionTitleToContent = 12;
  static const double betweenSections = 24;
  static const double bottomNavPadding = 88;

  // Rewards horizontal list
  static const double rewardCardWidth = 220;
  static const double rewardsListHeight = 280;

  // Tier carousel
  static const double tierCardWidth = 170;
  static const double tierCarouselHeight = 100;

  // Touch targets
  static const double minTouchTargetSize = 48;
}

/// French strings for loyalty card UI.
class LoyaltyStrings {
  LoyaltyStrings._();

  static const String pageTitle = 'Carte fidélité';
  static const String memberSince = 'Membre depuis';
  static const String visitsFormat = '{current} / {total}';
  static const String description =
      'À chaque visite en salon, votre jauge se remplit.\n'
      'Une fois complète, votre récompense est débloquée.';

  // Not logged in
  static const String loginPrompt =
      'Connectez-vous pour accéder à votre carte fidélité';
  static const String loginButton = 'Se connecter';

  static const List<String> _monthNames = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  /// Format "Membre depuis {day} {month} {year}" (e.g. "Membre depuis 15 janvier 2024")
  static String memberSinceDate(DateTime date) {
    final month = _monthNames[date.month - 1];
    return '$memberSince ${date.day} $month ${date.year}';
  }

  /// Format "currentVisits / totalRequiredVisits"
  static String visitsText(int current, int total) =>
      '$current / $total';
}
