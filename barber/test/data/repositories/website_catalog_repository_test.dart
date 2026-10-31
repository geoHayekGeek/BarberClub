import 'package:barber/data/repositories/website_catalog_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

String salon(String id) =>
    '<html><h1 class="page-title">Salon BarberClub $id</h1><p class="page-intro">Salon $id</p></html>';
String team(String id) =>
    '<html><a class="barber-card" href="../barbers/barber-$id.html"><h2 class="barber-name">$id</h2><p class="barber-role">Expert</p><img src="/portrait.jpg?v=2"></a></html>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'one broken salon or team page does not hide every other salon/team',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            final path = r.uri.path;
            final data = path == '/'
                ? '<a class="carte" href="pages/grenoble/"></a><a class="carte" href="pages/voiron/"></a><a href="pages/meylan/"></a>'
                : path.contains('voiron')
                ? '<html>Temporarily changed layout</html>'
                : path.contains('barbers.html')
                ? (path.contains('meylan')
                      ? '<html>Changed team</html>'
                      : team('tom'))
                : salon(path.split('/')[2]);
            h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: '<html>$data</html>',
              ),
            );
          },
        ),
      );
      final repo = WebsiteCatalogRepository(dio: dio);
      expect((await repo.getSalons()).map((s) => s.id), ['grenoble', 'meylan']);
      expect((await repo.getBarbers()).single.displayName, 'tom');
    },
  );

  test(
    'bad discovery markup is evicted so an immediate retry can recover',
    () async {
      var homeRequests = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            final data = r.uri.path == '/'
                ? (++homeRequests == 1
                      ? '<html>Unavailable</html>'
                      : '<a href="pages/voiron/"></a>')
                : salon('voiron');
            h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: '<html>$data</html>',
              ),
            );
          },
        ),
      );
      final repo = WebsiteCatalogRepository(dio: dio);
      await expectLater(repo.getSalons(), throwsFormatException);
      expect((await repo.getSalons()).single.id, 'voiron');
      expect(homeRequests, 2);
    },
  );

  test(
    'previously published content survives a temporary homepage outage',
    () async {
      var now = DateTime.utc(2026, 10, 31);
      var offline = false;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            if (offline) {
              h.reject(
                DioException(
                  requestOptions: r,
                  type: DioExceptionType.connectionError,
                ),
              );
            } else {
              h.resolve(
                Response(
                  requestOptions: r,
                  statusCode: 200,
                  data: r.uri.path == '/'
                      ? '<html><a href="pages/voiron/"></a></html>'
                      : salon('voiron'),
                ),
              );
            }
          },
        ),
      );
      final repo = WebsiteCatalogRepository(dio: dio, now: () => now);
      expect((await repo.getSalons()).single.id, 'voiron');
      now = now.add(const Duration(minutes: 6));
      offline = true;
      expect((await repo.getSalons()).single.id, 'voiron');
    },
  );

  test(
    'missing profile falls back to the published team card, not a blank page',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            if (r.uri.path.contains('/barbers/barber-')) {
              h.reject(
                DioException(
                  requestOptions: r,
                  type: DioExceptionType.badResponse,
                  response: Response(requestOptions: r, statusCode: 404),
                ),
              );
            } else {
              h.resolve(
                Response(
                  requestOptions: r,
                  statusCode: 200,
                  data: r.uri.path.endsWith('/barbers.html')
                      ? team('ju')
                      : salon('voiron'),
                ),
              );
            }
          },
        ),
      );
      final repo = WebsiteCatalogRepository(dio: dio);
      final barber = await repo.getBarberById('voiron--ju');
      expect(barber.displayName, 'ju');
      expect(barber.level, 'Expert');
      expect(barber.images.single, endsWith('/portrait.jpg?v=2'));
    },
  );
}
