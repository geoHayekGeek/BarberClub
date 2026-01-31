import '../models/salon.dart';

/// Salon repository interface.
/// Throws [ApiError] on failure.
abstract class SalonRepository {
  Future<List<Salon>> getSalons();
  Future<Salon> getSalonById(String id);
}
