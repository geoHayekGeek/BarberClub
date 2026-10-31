import 'package:barber/core/config/app_config.dart';
import 'package:barber/core/config/barber_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('asset versions and extra query parameters survive URL resolution', () {
    final image = Uri.parse(
      AppConfig.resolveImageUrl('/photo.jpg?v=3&size=small#portrait')!,
    );
    expect(image.queryParameters, {'v': '3', 'size': 'small'});
    expect(image.fragment, 'portrait');
    expect(
      AppConfig.resolvePublicAssetUrl('https://example.test/photo?v=4'),
      'https://example.test/photo?v=4',
    );
    expect(AppConfig.resolveImageUrl('javascript:alert(1)'), isNull);
    expect(AppConfig.resolveImageUrl('  '), isNull);
  });

  test(
    'reservation photos support short and full image paths without duplicating folders or query strings',
    () {
      for (final path in [
        '/barbers/gabriel.jpg?v=2',
        '/assets/images/barbers/gabriel.jpg?v=2',
        'images/barbers/gabriel.jpg?v=2',
      ]) {
        expect(
          AppConfig.resolveReservationBarberPhotoUrl(path),
          '${AppConfig.publicSiteBaseUrl}/assets/images/barbers/gabriel.jpg?v=2',
        );
      }
    },
  );

  test(
    'published reservation aliases match without guessing arbitrary prefixes',
    () {
      expect(BarberIdentity.matches('Clément', 'Clem'), isTrue);
      expect(BarberIdentity.matches('Julien', 'Ju'), isTrue);
      expect(BarberIdentity.matches('Alexandre', 'Alex'), isTrue);
      expect(BarberIdentity.matches(' Tom ', 'TOM'), isTrue);
      expect(BarberIdentity.matches('Jules', 'Julien'), isFalse);
      expect(BarberIdentity.matches('Tommy', 'Tom'), isFalse);
      expect(BarberIdentity.matches('', ''), isFalse);
    },
  );
}
