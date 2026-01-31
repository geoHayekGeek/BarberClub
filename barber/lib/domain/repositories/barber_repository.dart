import '../models/barber.dart';

/// Barber repository interface.
/// Throws [ApiError] on failure.
abstract class BarberRepository {
  Future<List<Barber>> getBarbers({String? salonId});
  Future<Barber> getBarberById(String id);
}
