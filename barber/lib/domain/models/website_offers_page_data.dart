enum WebsiteOfferSectionType { current, upcoming, teaser }

class WebsiteAlertConfig {
  const WebsiteAlertConfig({
    required this.apiBaseUrl,
    required this.eventName,
    required this.salonId,
    required this.successMessage,
    required this.buttonLabel,
    required this.emailPlaceholder,
  });

  final String apiBaseUrl;
  final String eventName;
  final String salonId;
  final String successMessage;
  final String buttonLabel;
  final String emailPlaceholder;
}

class WebsiteOfferSection {
  const WebsiteOfferSection._({
    required this.type,
    required this.sectionLabel,
    required this.headline,
    this.badge,
    this.subheadline,
    this.description,
    this.priceOld,
    this.priceNew,
    this.ctaLabel,
    this.footnote,
    this.details,
    this.countdownTarget,
    this.alertConfig,
    this.imageUrl,
  });

  factory WebsiteOfferSection.current({
    required String sectionLabel,
    required String badge,
    required String headline,
    required String subheadline,
    required String priceOld,
    required String priceNew,
    required String ctaLabel,
    required String footnote,
    required String details,
    required String imageUrl,
  }) {
    return WebsiteOfferSection._(
      type: WebsiteOfferSectionType.current,
      sectionLabel: sectionLabel,
      badge: badge,
      headline: headline,
      subheadline: subheadline,
      priceOld: priceOld,
      priceNew: priceNew,
      ctaLabel: ctaLabel,
      footnote: footnote,
      details: details,
      imageUrl: imageUrl,
    );
  }

  factory WebsiteOfferSection.upcoming({
    required String sectionLabel,
    required String badge,
    required String headline,
    required String subheadline,
    required String description,
    required String ctaLabel,
    required String details,
    required DateTime countdownTarget,
    required WebsiteAlertConfig alertConfig,
    required String imageUrl,
  }) {
    return WebsiteOfferSection._(
      type: WebsiteOfferSectionType.upcoming,
      sectionLabel: sectionLabel,
      badge: badge,
      headline: headline,
      subheadline: subheadline,
      description: description,
      ctaLabel: ctaLabel,
      details: details,
      countdownTarget: countdownTarget,
      alertConfig: alertConfig,
      imageUrl: imageUrl,
    );
  }

  factory WebsiteOfferSection.teaser({
    required String headline,
    required String description,
    required String sectionLabel,
  }) {
    return WebsiteOfferSection._(
      type: WebsiteOfferSectionType.teaser,
      sectionLabel: sectionLabel,
      headline: headline,
      description: description,
    );
  }

  final WebsiteOfferSectionType type;
  final String sectionLabel;
  final String headline;
  final String? badge;
  final String? subheadline;
  final String? description;
  final String? priceOld;
  final String? priceNew;
  final String? ctaLabel;
  final String? footnote;
  final String? details;
  final DateTime? countdownTarget;
  final WebsiteAlertConfig? alertConfig;
  final String? imageUrl;

  bool get isCurrent => type == WebsiteOfferSectionType.current;
  bool get isUpcoming => type == WebsiteOfferSectionType.upcoming;
  bool get isTeaser => type == WebsiteOfferSectionType.teaser;
}

class WebsiteGiftCardData {
  const WebsiteGiftCardData({
    required this.sectionLabel,
    required this.watermark,
    required this.label,
    required this.title,
    required this.price,
    required this.description,
    required this.linkLabel,
    required this.linkUrl,
  });

  final String sectionLabel;
  final String watermark;
  final String label;
  final String title;
  final String price;
  final String description;
  final String linkLabel;
  final String linkUrl;
}

class WebsiteOffersPageData {
  const WebsiteOffersPageData({
    required this.salonId,
    required this.pageUrl,
    required this.pageTitle,
    required this.pageDescription,
    required this.sections,
    required this.giftCard,
    required this.conditions,
    this.currentTabLabel,
    this.upcomingTabLabel,
  });

  factory WebsiteOffersPageData.fallbackGrenoble(Uri pageUrl) {
    final currentImage = pageUrl.resolve(
      '../../assets/images/salons/grenoble/chaise-grenoble.jpg?v=3',
    );
    final salonImage = pageUrl.resolve(
      '../../assets/images/salons/grenoble/salon-grenoble.jpg?v=3',
    );

    return WebsiteOffersPageData(
      salonId: 'grenoble',
      pageUrl: pageUrl,
      pageTitle: 'Offres & Événements | BarberClub Grenoble',
      pageDescription:
          'Événements exclusifs et offres BarberClub Grenoble. Cartes cadeaux, parrainage et surprises à venir.',
      currentTabLabel: 'Offre en cours',
      upcomingTabLabel: 'Offre à venir',
      sections: [
        WebsiteOfferSection.current(
          sectionLabel: 'Chaque mardi',
          badge: 'Mardi · 9h – 13h',
          headline: 'Barbe\nofferte',
          subheadline: 'avec ta coupe homme, chaque mardi matin au salon de Grenoble.',
          priceOld: '30€',
          priceNew: '20€',
          ctaLabel: 'Réserver mon mardi',
          footnote: 'Salon Grenoble · centre-ville',
          details:
              'Valable uniquement sur réservation en ligne d’une prestation Coupe + Barbe, le mardi de 9h à 13h. Les forfaits Coupe ne peuvent pas être transformés en Coupe + Barbe sur place. Non cumulable avec d’autres offres.',
          imageUrl: currentImage.toString(),
        ),
        WebsiteOfferSection.upcoming(
          sectionLabel: 'Bientôt',
          badge: 'Événement',
          headline: '2',
          subheadline: 'ANS',
          description: 'Quelque chose se prépare',
          ctaLabel: 'Être alerté',
          details: 'Détails révélés bientôt',
          countdownTarget: DateTime(2026, 7, 11, 0, 0, 0),
          alertConfig: const WebsiteAlertConfig(
            apiBaseUrl:
                'https://fortunate-benevolence-production-7df2.up.railway.app/api',
            eventName: '2ans_grenoble',
            salonId: 'grenoble',
            successMessage: 'Vous serez alerté !',
            buttonLabel: 'Être alerté',
            emailPlaceholder: 'Votre email',
          ),
          imageUrl: salonImage.toString(),
        ),
      ],
      giftCard: WebsiteGiftCardData(
        sectionLabel: 'Toute l\'année',
        watermark: 'BarberClub',
        label: 'Carte Cadeau',
        title: 'Offrez l\'expérience',
        price: 'Dès 20€',
        description: 'Montant libre, valable 1 an dans nos deux salons.',
        linkLabel: 'Réserver',
        linkUrl: pageUrl.resolve('reserver.html').toString(),
      ),
      conditions: const [
        'Non cumulable avec d’autres offres',
        'Valable sur réservation en ligne',
        '1 offre maximum par réservation',
        'Offres limitées dans le temps',
      ],
    );
  }

  factory WebsiteOffersPageData.fallbackMeylan(Uri pageUrl) {
    return WebsiteOffersPageData(
      salonId: 'meylan',
      pageUrl: pageUrl,
      pageTitle: 'Offres & Événements | BarberClub Meylan',
      pageDescription:
          'Offres exclusives BarberClub Meylan : cartes cadeaux, parrainage et événements à venir. Votre barbier premium à Corenc.',
      sections: [
        WebsiteOfferSection.teaser(
          sectionLabel: 'Restez connectés',
          headline: 'Restez connectés',
          description:
              'Des surprises et des événements exclusifs arrivent bientôt chez BarberClub Meylan. Suivez-nous pour ne rien rater.',
        ),
      ],
      giftCard: WebsiteGiftCardData(
        sectionLabel: 'Toute l\'année',
        watermark: 'BarberClub',
        label: 'Carte Cadeau',
        title: 'Offrez l\'expérience',
        price: 'Dès 20€',
        description: 'Montant libre, valable 1 an dans nos deux salons.',
        linkLabel: 'Réserver',
        linkUrl: pageUrl.resolve('reserver.html').toString(),
      ),
      conditions: const [
        'Non cumulable avec d’autres offres',
        'Valable sur réservation en ligne',
        '1 offre maximum par réservation',
      ],
    );
  }

  final String salonId;
  final Uri pageUrl;
  final String pageTitle;
  final String pageDescription;
  final List<WebsiteOfferSection> sections;
  final WebsiteGiftCardData giftCard;
  final List<String> conditions;
  final String? currentTabLabel;
  final String? upcomingTabLabel;

  bool get hasTabs =>
      sections.any((section) => section.isCurrent) &&
      sections.any((section) => section.isUpcoming);

  WebsiteOfferSection? get currentSection {
    for (final section in sections) {
      if (section.isCurrent) return section;
    }
    return null;
  }

  WebsiteOfferSection? get upcomingSection {
    for (final section in sections) {
      if (section.isUpcoming) return section;
    }
    return null;
  }

  WebsiteOfferSection? get teaserSection {
    for (final section in sections) {
      if (section.isTeaser) return section;
    }
    return null;
  }
}
