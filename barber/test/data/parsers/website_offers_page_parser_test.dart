import 'package:flutter_test/flutter_test.dart';

import 'package:barber/data/parsers/website_offers_page_parser.dart';
import 'package:barber/domain/models/website_offers_page_data.dart';

void main() {
  const parser = WebsiteOffersPageParser();

  test('parses the Grenoble offers page structure', () {
    const html = '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <title>Offres &amp; Événements | BarberClub Grenoble</title>
  <meta name="description" content="Événements exclusifs et offres BarberClub Grenoble. Cartes cadeaux, parrainage et surprises à venir.">
</head>
<body>
  <div class="offer-tabs rv" id="offerTabs" data-active="current" role="tablist" aria-label="Offres">
    <button class="offer-tab active" id="tabBtnCurrent" type="button" role="tab" aria-selected="true" aria-controls="tab-current">
      <span class="live-dot" aria-hidden="true"></span> Offre en cours
    </button>
    <button class="offer-tab" id="tabBtnUpcoming" type="button" role="tab" aria-selected="false" aria-controls="tab-upcoming">
      <svg viewBox="0 0 24 24"></svg>
      Offre à venir
    </button>
  </div>
  <section class="offer-panel" id="tab-current" role="tabpanel" aria-labelledby="tabBtnCurrent">
    <div class="mardi-section">
      <h2 class="section-title">Chaque mardi</h2>
      <a href="reserver.html" class="mardi-card" aria-label="Offre du mardi">
        <span class="mardi-bg" aria-hidden="true"><img src="../../assets/images/salons/grenoble/chaise-grenoble.jpg?v=3" alt="" loading="lazy"></span>
        <span class="mardi-badge"><span class="dot"></span> Mardi · 9h&nbsp;–&nbsp;13h</span>
        <span class="mardi-headline">Barbe<br>offerte</span>
        <span class="mardi-sub">avec ta coupe homme, chaque mardi matin au salon de Grenoble.</span>
        <span class="mardi-price">
          <s class="mardi-price-old">30€</s>
          <span class="mardi-price-arrow" aria-hidden="true">→</span>
          <span class="mardi-price-new">20€</span>
        </span>
        <span class="mystery-cta mardi-cta">Réserver mon mardi</span>
        <span class="mardi-foot">Salon Grenoble · centre-ville</span>
        <span class="mardi-conditions">Valable uniquement sur réservation en ligne d'une prestation Coupe + Barbe, le mardi de 9h à 13h.</span>
      </a>
    </div>
  </section>
  <section class="offer-panel" id="tab-upcoming" role="tabpanel" aria-labelledby="tabBtnUpcoming" hidden>
    <h2 class="section-title">Bientôt</h2>
    <div class="mystery" id="mystery">
      <div class="mystery-bg">
        <img src="../../assets/images/salons/grenoble/salon-grenoble.jpg?v=3" alt="" loading="eager">
      </div>
      <div class="mystery-content">
        <div class="mystery-badge"><span class="dot"></span> Événement</div>
        <div class="mystery-number" data-text="2" aria-label="2 ans">2</div>
        <div class="mystery-ans">Ans</div>
        <div class="mystery-tagline">Quelque chose se prépare</div>
        <div class="countdown" id="countdown"></div>
        <div id="alertZone">
          <button class="mystery-cta" id="notifyBtn" type="button">
            Être alerté
          </button>
          <form class="alert-form" id="alertForm" style="display:none">
            <input type="email" id="alertEmail" class="alert-input" placeholder="Votre email" required autocomplete="email">
          </form>
          <div class="alert-success" id="alertSuccess" style="display:none">
            Vous serez alerté !
          </div>
        </div>
        <div class="mystery-note">Détails révélés bientôt</div>
      </div>
    </div>
    <script>
      const TARGET = new Date(2026, 6, 11, 0, 0, 0).getTime();
      const API_BASE = window.location.hostname === 'localhost'
        ? 'http://localhost:3000/api'
        : 'https://fortunate-benevolence-production-7df2.up.railway.app/api';
    </script>
  </section>
  <div class="gift-section rv">
    <h2 class="section-title">Toute l'année</h2>
    <a href="reserver.html" class="gift-card" style="text-decoration:none;color:inherit">
      <span class="gift-watermark">BarberClub</span>
      <div class="gift-content">
        <div class="gift-label">Carte Cadeau</div>
        <div class="gift-title">Offrez l'expérience</div>
        <div class="gift-price">Dès 20€</div>
        <div class="gift-desc">Montant libre, valable 1 an dans nos deux salons.</div>
      </div>
    </a>
  </div>
  <div class="conds-section rv">
    <h2 class="section-title">Conditions</h2>
    <div class="conds-card">
      <div class="cond-row"><div class="cond-text">Non cumulable avec d'autres offres</div></div>
      <div class="cond-row"><div class="cond-text">Valable sur réservation en ligne</div></div>
      <div class="cond-row"><div class="cond-text">1 offre maximum par réservation</div></div>
      <div class="cond-row"><div class="cond-text">Offres limitées dans le temps</div></div>
    </div>
  </div>
</body>
</html>
''';

    final page = parser.parse(
      salonId: 'grenoble',
      pageUrl: Uri.parse(
        'https://barberclub-grenoble.fr/pages/grenoble/offres.html',
      ),
      html: html,
    );

    expect(page.pageTitle, 'Offres & Événements | BarberClub Grenoble');
    expect(page.currentTabLabel, 'Offre en cours');
    expect(page.upcomingTabLabel, 'Offre à venir');
    expect(page.sections, hasLength(2));
    expect(page.currentSection?.type, WebsiteOfferSectionType.current);
    expect(page.upcomingSection?.type, WebsiteOfferSectionType.upcoming);
    expect(page.currentSection?.headline, 'Barbe\nofferte');
    expect(page.currentSection?.priceOld, '30€');
    expect(page.currentSection?.priceNew, '20€');
    expect(
      page.currentSection?.imageUrl,
      'https://barberclub-grenoble.fr/assets/images/salons/grenoble/chaise-grenoble.jpg?v=3',
    );
    expect(page.upcomingSection?.countdownTarget, DateTime(2026, 7, 11, 0, 0));
    expect(page.upcomingSection?.alertConfig?.apiBaseUrl,
        'https://fortunate-benevolence-production-7df2.up.railway.app/api');
    expect(page.upcomingSection?.alertConfig?.eventName, '2ans_grenoble');
    expect(page.giftCard.title, "Offrez l'expérience");
    expect(page.conditions, hasLength(4));
  });

  test('parses the Meylan teaser page structure', () {
    const html = '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <title>Offres &amp; Événements | BarberClub Meylan</title>
  <meta name="description" content="Offres exclusives BarberClub Meylan : cartes cadeaux, parrainage et événements à venir. Votre barbier premium à Corenc.">
</head>
<body>
  <div class="teaser rv">
    <div class="teaser-icon"></div>
    <div class="teaser-title">Restez connectés</div>
    <div class="teaser-desc">Des surprises et des événements exclusifs arrivent bientôt chez BarberClub Meylan. Suivez-nous pour ne rien rater.</div>
  </div>
  <div class="gift-section rv">
    <h2 class="section-title">Toute l'année</h2>
    <a href="reserver.html" class="gift-card" style="text-decoration:none;color:inherit">
      <span class="gift-watermark">BarberClub</span>
      <div class="gift-content">
        <div class="gift-label">Carte Cadeau</div>
        <div class="gift-title">Offrez l'expérience</div>
        <div class="gift-price">Dès 20€</div>
        <div class="gift-desc">Montant libre, valable 1 an dans nos deux salons.</div>
      </div>
    </a>
  </div>
  <div class="conds-section rv">
    <h2 class="section-title">Conditions</h2>
    <div class="conds-card">
      <div class="cond-row"><div class="cond-text">Non cumulable avec d'autres offres</div></div>
      <div class="cond-row"><div class="cond-text">Valable sur réservation en ligne</div></div>
      <div class="cond-row"><div class="cond-text">1 offre maximum par réservation</div></div>
    </div>
  </div>
</body>
</html>
''';

    final page = parser.parse(
      salonId: 'meylan',
      pageUrl: Uri.parse(
        'https://barberclub-grenoble.fr/pages/meylan/offres.html',
      ),
      html: html,
    );

    expect(page.pageTitle, 'Offres & Événements | BarberClub Meylan');
    expect(page.sections, hasLength(1));
    expect(page.sections.first.type, WebsiteOfferSectionType.teaser);
    expect(page.sections.first.headline, 'Restez connectés');
    expect(page.giftCard.title, "Offrez l'expérience");
    expect(page.conditions, hasLength(3));
    expect(page.hasTabs, isFalse);
    expect(page.upcomingSection, isNull);
  });
}
