import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Website schedules are wall-clock times in France, regardless of the phone's
/// timezone. Keep the site's 12-hour cancellation window including DST changes.
class BookingPolicy {
  BookingPolicy._();
  static final tz.Location _paris = _loadParis();

  static tz.Location _loadParis() {
    tz_data.initializeTimeZones();
    return tz.getLocation('Europe/Paris');
  }

  static DateTime parisDate(int year, int month, int day) =>
      tz.TZDateTime(_paris, year, month, day);

  static bool canModify({
    required String date,
    required String startTime,
    required String status,
    DateTime? now,
  }) {
    if (status.toLowerCase() != 'confirmed') return false;
    final parsed = DateTime.tryParse('${date.split('T').first}T$startTime');
    if (parsed == null) return false;
    final scheduled = tz.TZDateTime(
      _paris,
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
    );
    return scheduled.difference(now ?? DateTime.now()) >=
        const Duration(hours: 12);
  }
}
