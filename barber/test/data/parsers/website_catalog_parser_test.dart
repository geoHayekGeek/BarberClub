import 'package:barber/data/parsers/website_catalog_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = WebsiteCatalogParser();
  final page = Uri.parse(
    'https://barberclub-grenoble.fr/pages/voiron/salon.html',
  );
  // Public semantic markup from the site's salon/team/profile pages.
  const salonHtml = '''<html><h1 class="page-title">Salon BarberClub Voiron</h1>
    <p class="page-intro">Le troisième BarberClub ouvre au 5 Av. Léon et Joanny Tardy, à Voiron.</p>
    <p class="page-subtitle">Ouverture <span>21 octobre 2026</span></p>
    <img class="desktop-hero-img" src="../../assets/images/salons/Voiron/voiron-facade-bleue.jpg">
    <div class="contact-card"><span class="contact-card-label">Adresse</span><p class="contact-card-value">5 Av. Léon et Joanny Tardy<br>38500 Voiron</p></div>
    <div class="contact-card"><span class="contact-card-label">Téléphone</span><p class="contact-card-value">09 55 20 86 20</p></div>
    <div class="hours-row"><span class="hours-day">Horaires</span><span class="hours-time open">9h – 19h</span></div>
    <p class="hours-note">Jours d'ouverture communiqués à l'ouverture.</p>
    <div class="story-block"><p>En 2024, Barber Club est né de cette exigence.</p></div>
    <details class="faq-item"><summary>Quand ouvre le salon ?</summary><p>Le mercredi 21 octobre 2026.</p></details></html>''';

  test('discovers every published salon without a two-salon cap', () {
    expect(
      parser.salonIds(
        '<a data-salon href="pages/grenoble/"></a><a data-salon href="pages/meylan/"></a><a data-salon href="pages/voiron/"></a>',
      ),
      ['grenoble', 'meylan', 'voiron'],
    );
  });

  test('Voiron uses exact public content without inventing opening days', () {
    final salon = parser.salon(id: 'voiron', pageUrl: page, html: salonHtml);
    expect(salon.city, 'Voiron');
    expect(salon.reservationSalonId, 'voiron');
    expect(salon.address, '5 Av. Léon et Joanny Tardy 38500 Voiron');
    expect(salon.phone, '09 55 20 86 20');
    expect(
      salon.imageUrl,
      'https://barberclub-grenoble.fr/assets/images/salons/Voiron/voiron-facade-bleue.jpg',
    );
    expect(salon.openingHoursStructured, isNull);
    expect(salon.openingHours, contains("Jours d'ouverture communiqués"));
    expect(salon.story, contains('2024'));
    expect(salon.questions.single.answer, contains('21 octobre'));
  });

  test(
    'team images keep query versions and unknown portraits stay placeholders',
    () {
      final salon = parser.salon(id: 'voiron', pageUrl: page, html: salonHtml);
      final entries = parser.barbers(
        salon: salon,
        pageUrl: page,
        html: '''
      <a class="barber-card" href="../barbers/barber-julien.html?salon=voiron"><img src="../../assets/images/barbers/julien.jpg?v=4"><h2 class="barber-name">Ju</h2><p class="barber-role">Co-Fondateur</p></a>
      <a class="barber-card" href="reserver.html?barber=Gabriel"><img src="../../assets/images/barbers/barber-soon.jpg?v=1"><h2 class="barber-name">Gabriel</h2></a>''',
      );
      expect(entries.first.barber.image, endsWith('/julien.jpg?v=4'));
      expect(entries.first.barber.salons.single.id, 'voiron');
      expect(entries.last.barber.image, endsWith('/barber-soon.jpg?v=1'));
      expect(entries.last.profileUrl, isNull);
      final detail = parser.barberDetail(
        summary: entries.first.barber,
        pageUrl: entries.first.profileUrl!,
        html:
            '''<p class="bio-text">Fondateur de BarberClub.</p><div class="gallery-item"><video><source src="../../assets/videos/Barbers-coupes/Coupe Ju/Coupe 2.mp4?v=3"></video></div>''',
      );
      expect(detail.bio, 'Fondateur de BarberClub.');
      expect(
        detail.galleryVideoUrls.single,
        contains('Coupe%20Ju/Coupe%202.mp4?v=3'),
      );
    },
  );
}
