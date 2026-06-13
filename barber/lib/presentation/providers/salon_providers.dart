import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/salon_repository_impl.dart';
import '../../domain/models/api_error.dart';
import '../../domain/models/salon.dart';
import '../../domain/repositories/salon_repository.dart';
import 'auth_providers.dart';

/// Salon repository provider.
final salonRepositoryProvider = Provider<SalonRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return SalonRepositoryImpl(dioClient: dioClient);
});

/// Selected salon ID in the app database (UUID).
/// The RDV screen resolves the reservation backend slug separately.
final selectedSalonIdForRdvProvider = StateProvider<String?>((ref) => null);

/// Selected salon slug used by the website reservation backend.
/// Resolves the app salon UUID to its public website identifier (e.g. meylan).
final selectedReservationSalonIdForRdvProvider = Provider<String?>((ref) {
  final selectedSalonId = ref.watch(selectedSalonIdForRdvProvider);
  if (selectedSalonId == null || selectedSalonId.trim().isEmpty) {
    return null;
  }

  final salonsAsync = ref.watch(salonsListProvider);
  return salonsAsync.maybeWhen(
    data: (salons) {
      for (final salon in salons) {
        if (salon.id == selectedSalonId) {
          return salon.reservationSalonId;
        }
      }
      return null;
    },
    orElse: () => null,
  );
});

/// Salons list provider. Cached; refetch only on refresh.
final salonsListProvider = FutureProvider.autoDispose<List<Salon>>((ref) async {
  final repository = ref.watch(salonRepositoryProvider);
  return repository.getSalons();
});

/// Salon detail by id. Cached per id; refetch on refresh.
final salonDetailProvider =
    FutureProvider.autoDispose.family<Salon, String>((ref, id) async {
  final repository = ref.watch(salonRepositoryProvider);
  return repository.getSalonById(id);
});

/// Map backend/network errors to user-friendly French messages for salons.
String getSalonErrorMessage(Object error, [StackTrace? stackTrace]) {
  if (error is ApiError) {
    switch (error.code) {
      case 'NOT_FOUND':
        return 'Salon introuvable.';
      case 'NETWORK_ERROR':
        return 'Impossible de se connecter. Vérifiez votre connexion.';
      default:
        return 'Une erreur est survenue. Veuillez réessayer.';
    }
  }
  if (error is DioException) {
    if (error.response?.statusCode == 404) {
      return 'Salon introuvable.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Impossible de se connecter. Vérifiez votre connexion.';
    }
  }
  return 'Une erreur est survenue. Veuillez réessayer.';
}
