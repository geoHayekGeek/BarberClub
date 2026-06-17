import '../models/reservation_session.dart';

abstract class ReservationAuthRepository {
  Future<ReservationSession?> restoreSession();

  Future<ReservationSession> login({
    required String email,
    required String password,
  });

  Future<ReservationSession> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
  });

  Future<ReservationSession?> refreshSession();

  Future<ReservationSession> ensureSessionFromAppAuth({
    required String email,
    required String password,
    required String phone,
    String? firstName,
    String? lastName,
    String? fullName,
  });

  Future<void> logout();

  Future<void> clearSession();

  Future<ReservationClientProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
  });

  Future<void> deleteAccount({required String password});
}
