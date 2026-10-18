import 'package:barber/core/storage/secure_token_repository.dart';
import 'package:barber/data/repositories/reservation_repository_impl.dart';
import 'package:barber/domain/repositories/reservation_auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnusedAuth extends Fake implements ReservationAuthRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cancels a later appointment with its own recovered credentials and salon',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'reservation_access_token': 'test-access',
      });
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://reservation.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            final data = request.path == '/client/bookings'
                ? {
                    'upcoming': [
                      {
                        'id': 'first',
                        'cancel_token': 'first-token',
                        'date': '2026-10-21',
                        'start_time': '09:00',
                        'salon_id': 'grenoble',
                      },
                      {
                        'id': 'later',
                        'cancel_token': 'later-token',
                        'date': '2026-10-28',
                        'start_time': '09:00',
                        'salon_id': 'voiron',
                      },
                    ],
                    'past': [],
                  }
                : {'success': true};
            handler.resolve(
              Response(requestOptions: request, statusCode: 200, data: data),
            );
          },
        ),
      );
      final repository = ReservationRepositoryImpl(
        tokenRepository: SecureTokenRepository(),
        authRepository: _UnusedAuth(),
        dio: dio,
      );
      await repository.cancelBooking(
        bookingId: 'later',
        cancelToken: '',
        salonId: 'voiron',
      );
      final cancel = requests.last;
      expect(cancel.path, '/bookings/later/cancel');
      expect(cancel.data, {'token': 'later-token', 'salon_id': 'voiron'});
      expect(cancel.headers['Authorization'], 'Bearer test-access');
      expect(
        await SecureTokenRepository().getReservationBookingCancelToken('first'),
        'first-token',
      );
      expect(
        await SecureTokenRepository().getReservationBookingCancelToken('later'),
        'later-token',
      );
      await repository.cancelBooking(
        bookingId: 'first',
        cancelToken: '',
        salonId: 'grenoble',
      );
      expect(requests.last.path, '/bookings/first/cancel');
      expect(requests.last.data, {
        'token': 'first-token',
        'salon_id': 'grenoble',
      });
    },
  );
}
