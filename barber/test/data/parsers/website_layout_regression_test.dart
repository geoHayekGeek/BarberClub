import 'package:barber/data/parsers/website_catalog_parser.dart';
import 'package:barber/data/parsers/website_offers_page_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const halloweenMarkup = '''<div data-salon="voiron" class="rv hw">
  <article class="hw-carte"><div class="hw-media"><picture>
    <img src="../../assets/images/offres/halloween/halloween-cire.jpg?v=2">
  </picture></div><div class="hw-corps">
    <p class="hw-kicker">En ce moment</p>
    <h2 class="hw-titre"><span class="hw-sr">-50 % sur ta cire, avec ta prestation</span>
      <span aria-hidden="true" class="hw-titre-vu">Sur ta cire</span></h2>
    <p aria-hidden="true" class="hw-sous-titre">avec ta prestation</p>
    <p class="hw-texte">Réserve ta prestation et repars avec ta cire coiffante à moitié prix.</p>
    <ul class="hw-salons"><li>Grenoble</li><li>Meylan</li><li>Voiron</li></ul>
    <a class="hw-cta" href="reserver.html">Réserver ma prestation <svg><title>arrow</title></svg></a>
    <p class="hw-conditions">-50 % sur une cire achetée avec ta prestation.</p>
  </div></article></div>''';

void main() {
  const catalog = WebsiteCatalogParser();
  const offers = WebsiteOffersPageParser();
  final home = Uri.parse('https://barberclub-grenoble.fr/');
  final page = home.resolve('pages/voiron/offres.html');

  test('current homepage discovers cards without data-salon', () {
    expect(
      catalog.salonIds('''
      <a class="carte carte-grenoble" href="pages/grenoble/"></a>
      <a href="/pages/meylan/salon" class="carte"></a>
      <a href="https://barberclub-grenoble.fr/pages/voiron/salon.html"></a>
      <a href="pages/grenoble/?from=footer"></a>
    ''', pageUrl: home),
      ['grenoble', 'meylan', 'voiron'],
    );
  });

  test('discovery rejects unrelated, external and unsafe links', () {
    expect(
      catalog.salonIds('''
      <a href="https://other.test/pages/fake/"></a>
      <a href="//other.test/pages/fake/"></a>
      <a href="javascript:alert(1)"></a>
      <a href="pages/barbers/barber-ju.html"></a>
      <a href="pages/voiron/offres.html"></a>
      <a href="pages/../admin/"></a>
      <a href="pages/voiron/"></a>
    ''', pageUrl: home),
      ['voiron'],
    );
  });

  test(
    'current Voiron promotion preserves site copy, image and conditions',
    () {
      final data = offers.parse(
        salonId: 'voiron',
        pageUrl: page,
        html:
            '''
      <title>Offres Voiron | BarberClub</title>$halloweenMarkup
      <div class="idle-card" hidden><h2 class="idle-title">Pas d'offre en cours</h2></div>
    ''',
      );
      expect(data.sections, hasLength(1));
      final current = data.currentSection!;
      expect(current.headline, '-50 %');
      expect(current.subheadline, 'Sur ta cire — avec ta prestation');
      expect(current.details, contains('cire coiffante à moitié prix'));
      expect(current.details, contains('-50 % sur une cire'));
      expect(current.ctaLabel, 'Réserver ma prestation');
      expect(current.priceOld, isEmpty);
      expect(current.priceNew, isEmpty);
      expect(
        current.imageUrl,
        home
            .resolve('assets/images/offres/halloween/halloween-cire.jpg?v=2')
            .toString(),
      );
      expect(data.teaserSection, isNull);
    },
  );

  test(
    'hidden campaigns do not revive discounts; visible idle copy is kept',
    () {
      final data = offers.parse(
        salonId: 'voiron',
        pageUrl: page,
        html:
            '''
      <div hidden>$halloweenMarkup</div>
      <div class="idle-card"><h2 class="idle-title">Pas d'offre en cours</h2>
      <p class="idle-desc">Les prochaines offres s'afficheront ici.</p></div>
    ''',
      );
      expect(data.currentSection, isNull);
      expect(data.teaserSection?.headline, "Pas d'offre en cours");
    },
  );

  test(
    'multiple promotions and reordered attributes/classes are preserved',
    () {
      final data = offers.parse(
        salonId: 'grenoble',
        pageUrl: page,
        html:
            '''
      $halloweenMarkup
      <section id="tab-current" class="rv offer-panel"><h2 class="section-title">Chaque mardi</h2>
      <a class="rv mardi-card" href="reserver.html"><span class="mardi-headline">Barbe<br>offerte</span>
      <span class="mardi-price-new">20&#x20AC;</span></a></section>
      <section hidden id="tab-upcoming" class="rv offer-panel"><div class="mystery-number">Événement</div></section>
      <div class="gift-section"><h2 class="section-title">Toute l'année</h2>
      <a class="rv gift-card" href="reserver.html"><div class="gift-title">Carte &amp; cadeaux</div></a></div>
    ''',
      );
      expect(data.sections.where((s) => s.isCurrent), hasLength(2));
      expect(data.sections[1].headline, 'Barbe\nofferte');
      expect(data.sections[1].priceNew, '20€');
      expect(data.hasTabs, isTrue);
      expect(data.giftCard.title, 'Carte & cadeaux');
      expect(data.giftCard.linkUrl, page.resolve('reserver.html').toString());
    },
  );

  test('expired countdowns are not advertised as upcoming events', () {
    final data = offers.parse(
      salonId: 'grenoble',
      pageUrl: page,
      now: DateTime.utc(2026, 7, 11),
      html: '''
        <section id="tab-upcoming"><div class="mystery-number">2</div></section>
        <script>const TARGET = new Date(2026, 6, 11, 0, 0, 0).getTime();</script>
      ''',
    );
    expect(data.upcomingSection, isNull);
  });
}
