import 'package:barber/data/parsers/website_offers_page_parser.dart';
import 'package:barber/domain/models/website_offers_page_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = WebsiteOffersPageParser();
  final url = Uri.parse(
    'https://barberclub-grenoble.fr/pages/voiron/offres.html',
  );
  const html = '''<html><title>Offres Voiron</title>
    <span class="launch-kicker">Pour fêter l'ouverture</span>
    <h1 class="launch-num">-50%</h1><p class="launch-num-sub">sur toutes les prestations</p>
    <div class="launch-days"><div data-date="2026-10-21"></div><div data-date="2026-10-24"></div></div>
    <span class="launch-month">Octobre 2026</span><p class="launch-status">Du 21 au 24 octobre</p>
    <s class="lp-old">25€</s><span class="lp-new">12,50€</span>
    <div class="launch-ctas"><a class="btn-primary">Réserver</a></div>
    <p class="launch-fine">Toutes les prestations du salon de Voiron à moitié prix, du mercredi 21 au samedi 24 octobre 2026 inclus.</p>
    <h2 class="idle-title">Pas d'offre en cours</h2><p class="idle-desc">Les prochaines offres du salon de Voiron s'afficheront ici.</p></html>''';

  test(
    'reads Voiron opening promotion without substituting Grenoble content',
    () {
      final data = parser.parse(
        salonId: 'voiron',
        pageUrl: url,
        html: html,
        now: DateTime.utc(2026, 10, 18),
      );
      expect(data.salonId, 'voiron');
      expect(data.currentSection?.headline, '-50%');
      expect(data.currentSection?.priceNew, '12,50€');
      expect(data.currentSection?.details, contains('Voiron'));
      expect(data.giftCard.title, isEmpty);
    },
  );
  test(
    'opening promotion expires at midnight in Paris, even on another phone timezone',
    () {
      final live = parser.parse(
        salonId: 'voiron',
        pageUrl: url,
        html: html,
        now: DateTime.utc(2026, 10, 24, 21, 59),
      );
      final ended = parser.parse(
        salonId: 'voiron',
        pageUrl: url,
        html: html,
        now: DateTime.utc(2026, 10, 24, 22),
      );
      expect(live.currentSection, isNotNull);
      expect(ended.currentSection, isNull);
      expect(ended.sections.single.type, WebsiteOfferSectionType.teaser);
      expect(ended.sections.single.headline, "Pas d'offre en cours");
    },
  );
  test('unrecognized website markup cannot resurrect old promotions', () {
    final data = parser.parse(
      salonId: 'voiron',
      pageUrl: url,
      html: '<html><title>New page</title></html>',
    );
    expect(data.sections, isEmpty);
  });
}
