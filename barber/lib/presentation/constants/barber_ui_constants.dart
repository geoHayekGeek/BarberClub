/// UI constants and French strings for Nos Coiffeurs feature.
library;

/// Design tokens (no magic numbers in widgets).
class BarberUIConstants {
  BarberUIConstants._();

  // Card
  static const double cardWidth = 280;
  static const double cardBorderRadius = 16;
  static const double cardImageAspectRatio = 3 / 4; // Portrait
  static const double cardPadding = 16;

  // Carousel
  /// Fraction of screen height for the Nos coiffeurs carousel (0.55–0.65).
  static const double carouselHeightFraction = 0.6;

  // Spacing
  static const double horizontalGutter = 20;
  static const double cardSpacing = 16;
  static const double sectionSpacing = 24;
  static const double chipSpacing = 8;
  static const double chipRunSpacing = 8;

  // Hero
  static const double heroHeight = 320;
  static const double heroOverlayOpacity = 0.6;
  static const double backButtonMinSize = 48;

  // Gallery
  static const double galleryItemHeight = 160;
  static const double galleryItemWidth = 140;
  static const double galleryItemBorderRadius = 12;
  static const double galleryItemSpacing = 12;
  static const double galleryVisibleCount = 4;

  // CTA
  static const double ctaHeight = 52;
  static const double ctaBorderRadius = 12;
}

/// French strings for barber UI.
class BarberStrings {
  BarberStrings._();

  static const String pageTitle = 'Nos coiffeurs';
  static const String emptyList = 'Aucun coiffeur disponible pour le moment.';
  static const String retry = 'Réessayer';
  static const String centresInteret = 'Centres d\'intérêt';
  static const String galerie = 'Galerie';
  static const String ctaRdv = 'Prendre RDV avec ce coiffeur';
  static const String ctaSoon = 'Bientôt disponible';

  static String levelLabel(String level) {
    switch (level.toLowerCase()) {
      case 'junior':
        return 'Junior';
      case 'senior':
        return 'Senior';
      case 'expert':
        return 'Expert';
      default:
        return level;
    }
  }
}
