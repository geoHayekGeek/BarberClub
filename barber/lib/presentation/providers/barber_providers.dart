import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/barber.dart';
import '../../domain/models/api_error.dart';
import '../../domain/repositories/barber_repository.dart';
import '../../data/repositories/barber_repository_impl.dart';
import 'auth_providers.dart';

/// Barber repository provider
final barberRepositoryProvider = Provider<BarberRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return BarberRepositoryImpl(dioClient: dioClient);
});

/// Barbers list provider. Pass salonId to filter by salon (optional).
final barbersListProvider =
    FutureProvider.autoDispose<List<Barber>>((ref) async {
  final repository = ref.watch(barberRepositoryProvider);
  return repository.getBarbers();
});

/// Barber detail by id.
final barberDetailProvider =
    FutureProvider.autoDispose.family<Barber, String>((ref, id) async {
  final repository = ref.watch(barberRepositoryProvider);
  return repository.getBarberById(id);
});

/// Map backend/network errors to French messages for barbers.
String getBarberErrorMessage(Object error, [StackTrace? stackTrace]) {
  if (error is ApiError) {
    switch (error.code) {
      case 'NOT_FOUND':
        return 'Coiffeur introuvable.';
      case 'NETWORK_ERROR':
        return 'Impossible de charger les coiffeurs.';
      default:
        return 'Une erreur est survenue. Veuillez réessayer.';
    }
  }
  if (error is DioException) {
    if (error.response?.statusCode == 404) {
      return 'Coiffeur introuvable.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Impossible de charger les coiffeurs.';
    }
  }
  return 'Une erreur est survenue. Veuillez réessayer.';
}
