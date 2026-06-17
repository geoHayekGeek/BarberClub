import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/token_repository.dart';
import '../../domain/models/api_error.dart';
import '../../domain/models/reservation_models.dart';
import '../../domain/repositories/reservation_auth_repository.dart';
import '../../domain/repositories/reservation_repository.dart';

class ReservationRepositoryImpl implements ReservationRepository {
  ReservationRepositoryImpl({
    required ReservationTokenRepository tokenRepository,
    required ReservationAuthRepository authRepository,
    Dio? dio,
  }) : _tokenRepository = tokenRepository,
       _authRepository = authRepository,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: AppConfig.reservationApiBaseUrl,
               connectTimeout: const Duration(
                 milliseconds: AppConfig.apiTimeoutMs,
               ),
               receiveTimeout: const Duration(
                 milliseconds: AppConfig.apiTimeoutMs,
               ),
               sendTimeout: const Duration(
                 milliseconds: AppConfig.apiTimeoutMs,
               ),
               headers: const {
                 'Content-Type': 'application/json',
                 'Accept': 'application/json',
               },
             ),
           );

  final Dio _dio;
  final ReservationTokenRepository _tokenRepository;
  final ReservationAuthRepository _authRepository;

  @override
  Future<List<ReservationBarber>> getBarbers({required String salonId}) async {
    try {
      final response = await _dio.get(
        '/barbers',
        queryParameters: {'salon_id': salonId},
      );
      return _extractList(
        response.data,
      ).map((item) => ReservationBarber.fromJson(item)).toList(growable: false);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  @override
  Future<List<ReservationService>> getServices({
    required String salonId,
    String? barberId,
  }) async {
    try {
      final queryParameters = <String, dynamic>{'salon_id': salonId};
      if (barberId != null && barberId.trim().isNotEmpty) {
        queryParameters['barber_id'] = barberId;
      }

      final response = await _dio.get(
        '/services',
        queryParameters: queryParameters,
      );

      return _extractList(response.data)
          .map((item) => ReservationService.fromJson(item))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  @override
  Future<List<ReservationSlot>> getAvailability({
    required String salonId,
    required String serviceId,
    required String date,
    String? barberId,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'salon_id': salonId,
        'service_id': serviceId,
        'date': date,
      };
      if (barberId != null && barberId.trim().isNotEmpty) {
        queryParameters['barber_id'] = barberId;
      }

      final response = await _dio.get(
        '/availability',
        queryParameters: queryParameters,
      );

      return _extractList(
        response.data,
      ).map((item) => ReservationSlot.fromJson(item)).toList(growable: false);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  @override
  Future<Map<String, ReservationMonthAvailability>> getMonthAvailability({
    required String salonId,
    required String serviceId,
    required int year,
    required int month,
    String? barberId,
    bool includeAlternatives = false,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'salon_id': salonId,
        'service_id': serviceId,
        'year': year,
        'month': month - 1,
        'include_alternatives': includeAlternatives.toString(),
      };
      if (barberId != null && barberId.trim().isNotEmpty) {
        queryParameters['barber_id'] = barberId;
      }

      final response = await _dio.get(
        '/availability/month',
        queryParameters: queryParameters,
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const {};
      }

      return data.map((date, rawValue) {
        final value = rawValue is Map<String, dynamic>
            ? ReservationMonthAvailability.fromJson(rawValue)
            : const ReservationMonthAvailability(
                total: 0,
                status: 'full',
                alternatives: [],
              );
        return MapEntry(date, value);
      });
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  @override
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
  }) async {
    final requestBody = {
      'salon_id': salonId,
      'barber_id': barberId,
      'service_id': serviceId,
      'date': date,
      'start_time': startTime,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
    };

    try {
      final requestOptions = await _buildReservationRequestOptions();
      final response = await _dio.post(
        '/bookings',
        data: requestBody,
        options: requestOptions,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ReservationBooking.fromJson(data);
      }
      throw const ApiError(
        code: 'UNKNOWN_ERROR',
        message: 'Une erreur est survenue. Veuillez reessayer.',
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        final refreshed = await _authRepository.refreshSession();
        if (refreshed != null) {
          final retryResponse = await _dio.post(
            '/bookings',
            data: requestBody,
            options: Options(
              headers: {'Authorization': 'Bearer ${refreshed.accessToken}'},
            ),
          );

          final retryData = retryResponse.data;
          if (retryData is Map<String, dynamic>) {
            return ReservationBooking.fromJson(retryData);
          }
        }
      }
      throw _mapDioError(error);
    }
  }

  @override
  Future<ReservationClientBookingsPage> getClientBookings({
    String? salonId,
  }) async {
    final queryParameters = <String, dynamic>{};
    final normalizedSalonId = salonId?.trim();
    if (normalizedSalonId != null && normalizedSalonId.isNotEmpty) {
      queryParameters['salon_id'] = normalizedSalonId;
    }

    try {
      final requestOptions = await _buildReservationRequestOptions();
      final response = await _dio.get(
        '/client/bookings',
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
        options: requestOptions,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ReservationClientBookingsPage.fromJson(data);
      }
      throw const ApiError(
        code: 'UNKNOWN_ERROR',
        message: 'Une erreur est survenue. Veuillez reessayer.',
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        final refreshed = await _authRepository.refreshSession();
        if (refreshed != null) {
          final retryResponse = await _dio.get(
            '/client/bookings',
            queryParameters: queryParameters.isEmpty ? null : queryParameters,
            options: Options(
              headers: {'Authorization': 'Bearer ${refreshed.accessToken}'},
            ),
          );

          final retryData = retryResponse.data;
          if (retryData is Map<String, dynamic>) {
            return ReservationClientBookingsPage.fromJson(retryData);
          }
        }
      }
      throw _mapDioError(error);
    }
  }

  @override
  Future<void> cancelBooking({
    required String bookingId,
    required String cancelToken,
    String? salonId,
  }) async {
    final body = <String, dynamic>{'token': cancelToken};
    final normalizedSalonId = salonId?.trim();
    if (normalizedSalonId != null && normalizedSalonId.isNotEmpty) {
      body['salon_id'] = normalizedSalonId;
    }

    try {
      await _dio.post('/bookings/$bookingId/cancel', data: body);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        final refreshed = await _authRepository.refreshSession();
        if (refreshed != null) {
          await _dio.post(
            '/bookings/$bookingId/cancel',
            data: body,
            options: Options(
              headers: {'Authorization': 'Bearer ${refreshed.accessToken}'},
            ),
          );
          return;
        }
      }
      throw _mapDioError(error);
    }
  }

  Future<Options> _buildReservationRequestOptions() async {
    final accessToken = await _tokenRepository.getReservationAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return Options();
    }

    return Options(headers: {'Authorization': 'Bearer $accessToken'});
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is List) {
        return inner.whereType<Map<String, dynamic>>().toList(growable: false);
      }
      final barbers = data['barbers'];
      if (barbers is List) {
        return barbers.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );
      }
    }
    return const [];
  }

  ApiError _mapDioError(DioException error) {
    final response = error.response;
    if (response != null) {
      final statusCode = response.statusCode ?? 500;
      final code = switch (statusCode) {
        400 => 'VALIDATION_ERROR',
        401 => 'UNAUTHORIZED',
        403 => 'FORBIDDEN',
        404 => 'NOT_FOUND',
        409 => 'CONFLICT',
        429 => 'RATE_LIMITED',
        _ => 'UNKNOWN_ERROR',
      };

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final message =
            data['error']?.toString() ??
            data['message']?.toString() ??
            error.message ??
            'Une erreur est survenue.';
        final details = data['details'];
        final fields = details is Map<String, dynamic> ? details : null;
        return ApiError(code: code, message: message, fields: fields);
      }

      return ApiError(
        code: code,
        message: error.message ?? 'Une erreur est survenue.',
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const ApiError(
        code: 'NETWORK_ERROR',
        message: 'Impossible de se connecter. Verifiez votre connexion.',
      );
    }

    return ApiError(
      code: 'UNKNOWN_ERROR',
      message: error.message ?? 'Une erreur est survenue.',
    );
  }
}
