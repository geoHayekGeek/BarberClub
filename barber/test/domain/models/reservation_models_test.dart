import 'package:barber/domain/models/reservation_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sorts upcoming oldest first and booking history newest first', () {
    final page = ReservationClientBookingsPage.fromJson({
      'upcoming': [
        _booking('later', '2026-09-10', '14:00:00'),
        _booking('next', '2026-09-08', '09:30:00'),
      ],
      'past': [
        _booking('oldest', '2026-07-01', '11:00:00'),
        _booking('newest', '2026-08-20', '16:00:00'),
        _booking('middle', '2026-08-05', '10:00:00'),
      ],
    });

    expect(page.upcoming.map((booking) => booking.id), ['next', 'later']);
    expect(page.past.map((booking) => booking.id), [
      'newest',
      'middle',
      'oldest',
    ]);
    expect(page.nextUpcoming?.id, 'next');
  });
}

Map<String, dynamic> _booking(String id, String date, String startTime) {
  return {
    'id': id,
    'date': date,
    'start_time': startTime,
    'created_at': '${date}T$startTime',
  };
}
