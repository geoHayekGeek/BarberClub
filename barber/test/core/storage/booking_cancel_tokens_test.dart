import 'dart:convert';
import 'package:barber/core/storage/secure_token_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'concurrent saves keep every future appointment token after restart',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final repository = SecureTokenRepository();
      await Future.wait([
        for (var i = 1; i <= 8; i++)
          repository.saveReservationBookingCancelToken(
            bookingId: 'booking-$i',
            cancelToken: 'token-$i',
          ),
      ]);
      final restarted = SecureTokenRepository();
      for (var i = 1; i <= 8; i++) {
        expect(
          await restarted.getReservationBookingCancelToken('booking-$i'),
          'token-$i',
        );
      }
      expect(
        await restarted.getReservationBookingCancelToken('unknown'),
        isNull,
      );
    },
  );

  test(
    'old cache stays readable and migrates each appointment separately',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'reservation_booking_cancel_tokens': jsonEncode({
          'earlier': 'token-a',
          'later': 'token-b',
        }),
      });
      final repository = SecureTokenRepository();
      expect(
        await repository.getReservationBookingCancelToken('later'),
        'token-b',
      );
      expect(
        await repository.getReservationBookingCancelToken('earlier'),
        'token-a',
      );
      expect(
        await const FlutterSecureStorage().read(
          key: 'reservation_booking_cancel_tokens_later',
        ),
        'token-b',
      );
    },
  );
}
