import 'package:barber/core/config/booking_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every later appointment remains independently cancelable', () {
    final now = DateTime.utc(2026, 10, 18, 10);
    for (final day in [19, 22, 28]) {
      expect(
        BookingPolicy.canModify(
          date: '2026-10-$day',
          startTime: '15:00:00',
          status: 'confirmed',
          now: now,
        ),
        isTrue,
      );
    }
  });
  test(
    'cutoff uses Paris time and handles winter daylight saving transition',
    () {
      expect(
        BookingPolicy.canModify(
          date: '2026-10-24',
          startTime: '15:00',
          status: 'confirmed',
          now: DateTime.utc(2026, 10, 24, 1),
        ),
        isTrue,
      );
      expect(
        BookingPolicy.canModify(
          date: '2026-10-24',
          startTime: '15:00',
          status: 'confirmed',
          now: DateTime.utc(2026, 10, 24, 1, 1),
        ),
        isFalse,
      );
      expect(
        BookingPolicy.canModify(
          date: '2026-10-25',
          startTime: '15:00',
          status: 'confirmed',
          now: DateTime.utc(2026, 10, 25, 2),
        ),
        isTrue,
      );
      expect(
        BookingPolicy.canModify(
          date: '2026-10-25',
          startTime: '15:00',
          status: 'cancelled',
          now: DateTime.utc(2026, 10, 18),
        ),
        isFalse,
      );
    },
  );
}
