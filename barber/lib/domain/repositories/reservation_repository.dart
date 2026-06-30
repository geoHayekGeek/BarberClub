import '../models/reservation_models.dart';

abstract class ReservationRepository {
  Future<List<ReservationBarber>> getBarbers({required String salonId});

  Future<List<ReservationService>> getServices({
    required String salonId,
    String? barberId,
  });

  Future<List<ReservationSlot>> getAvailability({
    required String salonId,
    required String serviceId,
    required String date,
    String? barberId,
  });

  Future<Map<String, ReservationMonthAvailability>> getMonthAvailability({
    required String salonId,
    required String serviceId,
    required int year,
    required int month,
    String? barberId,
    bool includeAlternatives = false,
  });

  Future<ReservationBooking> createBooking({
    required String salonId,
    required String barberId,
    required String serviceId,
    required String date,
    required String startTime,
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
  });

  Future<ReservationClientBookingsPage> getClientBookings({String? salonId});

  Future<ReservationBooking> rescheduleBooking({
    required String bookingId,
    required String cancelToken,
    required String date,
    required String startTime,
    String? salonId,
  });

  Future<void> cancelBooking({
    required String bookingId,
    required String cancelToken,
    String? salonId,
  });
}
