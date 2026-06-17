import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/api_error.dart';
import '../../domain/models/reservation_models.dart';
import 'reservation_auth_providers.dart';
import '../../data/repositories/reservation_repository_impl.dart';
import '../../domain/repositories/reservation_repository.dart';

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  return ReservationRepositoryImpl(
    tokenRepository: ref.watch(reservationTokenRepositoryProvider),
    authRepository: ref.watch(reservationAuthRepositoryProvider),
  );
});

final reservationClientBookingsProvider = FutureProvider.autoDispose
    .family<ReservationClientBookingsPage, String?>((ref, salonId) async {
      final session = ref.watch(reservationSessionProvider);
      if (session.status != ReservationSessionStatus.authenticated ||
          session.user == null) {
        throw const ApiError(
          code: 'UNAUTHORIZED',
          message: 'Session expirée. Veuillez vous reconnecter.',
        );
      }

      final repository = ref.watch(reservationRepositoryProvider);
      final selectedSalonId = salonId?.trim();
      return repository.getClientBookings(
        salonId: selectedSalonId == null || selectedSalonId.isEmpty
            ? null
            : selectedSalonId,
      );
    });
