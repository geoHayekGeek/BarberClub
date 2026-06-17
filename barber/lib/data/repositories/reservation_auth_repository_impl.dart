import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/token_repository.dart';
import '../../domain/models/api_error.dart';
import '../../domain/models/reservation_session.dart';
import '../../domain/repositories/reservation_auth_repository.dart';

class ReservationAuthRepositoryImpl implements ReservationAuthRepository {
  ReservationAuthRepositoryImpl({
    required ReservationTokenRepository tokenRepository,
    Dio? dio,
  }) : _tokenRepository = tokenRepository,
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

  final ReservationTokenRepository _tokenRepository;
  final Dio _dio;

  @override
  Future<ReservationSession?> restoreSession() async {
    final accessToken = await _tokenRepository.getReservationAccessToken();
    final refreshToken = await _tokenRepository.getReservationRefreshToken();
    if (accessToken == null || refreshToken == null) {
      return null;
    }

    try {
      final user = await _loadCurrentUser(accessToken);
      return ReservationSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
      );
    } on ApiError catch (error) {
      if (error.code == 'UNAUTHORIZED') {
        final refreshed = await refreshSession();
        if (refreshed != null) {
          return refreshed;
        }
        return null;
      }
      if (error.code == 'NETWORK_ERROR') {
        return null;
      }
      await clearSession();
      return null;
    } on DioException {
      // Keep the cached tokens in place when the network is temporarily down.
      return null;
    }
  }

  @override
  Future<ReservationSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email.trim(), 'password': password, 'type': 'client'},
      );

      return await _completeSessionFromAuthResponse(response.data);
    } on DioException catch (error) {
      throw _handleDioError(error);
    }
  }

  @override
  Future<ReservationSession> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'phone': phone.trim(),
          'email': email.trim(),
          'password': password,
        },
      );

      return await _completeSessionFromAuthResponse(response.data);
    } on DioException catch (error) {
      throw _handleDioError(error);
    }
  }

  @override
  Future<ReservationSession?> refreshSession() async {
    final refreshToken = await _tokenRepository.getReservationRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      return await _completeSessionFromAuthResponse(response.data);
    } on ApiError catch (error) {
      if (error.code == 'NETWORK_ERROR') {
        return null;
      }
      await clearSession();
      return null;
    } on DioException {
      return null;
    }
  }

  @override
  Future<ReservationSession> ensureSessionFromAppAuth({
    required String email,
    required String password,
    required String phone,
    String? firstName,
    String? lastName,
    String? fullName,
  }) async {
    try {
      return await login(email: email, password: password);
    } on ApiError catch (error) {
      final shouldRegister =
          error.code == 'UNAUTHORIZED' ||
          error.code == 'NOT_FOUND' ||
          error.code == 'INVALID_CREDENTIALS';

      if (!shouldRegister) {
        rethrow;
      }

      final resolved = _resolveNameParts(
        firstName: firstName,
        lastName: lastName,
        fullName: fullName,
      );
      if (resolved == null) {
        throw const ApiError(
          code: 'VALIDATION_ERROR',
          message:
              'Impossible de synchroniser le compte réservation sans prénom et nom.',
        );
      }

      return register(
        firstName: resolved.$1,
        lastName: resolved.$2,
        phone: phone,
        email: email,
        password: password,
      );
    }
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenRepository.getReservationRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _dio.post('/auth/logout', data: {'refresh_token': refreshToken});
      }
    } on DioException {
      // Ignore backend logout failures and always clear local session.
    } finally {
      await clearSession();
    }
  }

  @override
  Future<void> clearSession() async {
    await _tokenRepository.clearReservationTokens();
  }

  @override
  Future<ReservationClientProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    final hasChanges =
        (firstName != null && firstName.trim().isNotEmpty) ||
        (lastName != null && lastName.trim().isNotEmpty) ||
        (email != null && email.trim().isNotEmpty);
    if (!hasChanges) {
      throw const ApiError(
        code: 'VALIDATION_ERROR',
        message: 'Aucune donnée à mettre à jour.',
      );
    }

    final accessToken = await _tokenRepository.getReservationAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiError(
        code: 'UNAUTHORIZED',
        message: 'Session expirée. Veuillez vous reconnecter.',
      );
    }

    try {
      final response = await _dio.put(
        '/client/profile',
        data: {
          if (firstName != null && firstName.trim().isNotEmpty)
            'first_name': firstName.trim(),
          if (lastName != null && lastName.trim().isNotEmpty)
            'last_name': lastName.trim(),
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ReservationClientProfile.fromJson(data);
      }
      throw const ApiError(
        code: 'UNKNOWN_ERROR',
        message: 'Une erreur est survenue. Veuillez réessayer.',
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        final refreshed = await refreshSession();
        if (refreshed != null) {
          return updateProfile(
            firstName: firstName,
            lastName: lastName,
            email: email,
          );
        }
      }
      throw _handleDioError(error);
    }
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final accessToken = await _tokenRepository.getReservationAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiError(
        code: 'UNAUTHORIZED',
        message: 'Session expirée. Veuillez vous reconnecter.',
      );
    }

    try {
      await _dio.delete(
        '/client/delete-account',
        data: {'password': password},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      await clearSession();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        final refreshed = await refreshSession();
        if (refreshed != null) {
          await deleteAccount(password: password);
          return;
        }
      }
      throw _handleDioError(error);
    }
  }

  Future<ReservationSession> _completeSessionFromAuthResponse(
    Object? rawData,
  ) async {
    if (rawData is! Map<String, dynamic>) {
      throw const ApiError(
        code: 'UNKNOWN_ERROR',
        message: 'Une erreur est survenue. Veuillez réessayer.',
      );
    }

    final accessToken =
        rawData['access_token'] as String? ?? rawData['accessToken'] as String?;
    final refreshToken =
        rawData['refresh_token'] as String? ??
        rawData['refreshToken'] as String?;

    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiError(
        code: 'UNKNOWN_ERROR',
        message: 'Session introuvable. Veuillez réessayer.',
      );
    }

    final user = await _loadCurrentUser(accessToken);
    final resolvedRefreshToken =
        refreshToken ??
        (await _tokenRepository.getReservationRefreshToken()) ??
        '';

    if (resolvedRefreshToken.isEmpty) {
      throw const ApiError(
        code: 'UNKNOWN_ERROR',
        message: 'Session introuvable. Veuillez réessayer.',
      );
    }

    await _tokenRepository.saveReservationAccessToken(accessToken);
    await _tokenRepository.saveReservationRefreshToken(resolvedRefreshToken);

    return ReservationSession(
      accessToken: accessToken,
      refreshToken: resolvedRefreshToken,
      user: user,
    );
  }

  Future<ReservationClientProfile> _loadCurrentUser(String accessToken) async {
    try {
      final response = await _dio.get(
        '/client/profile',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ReservationClientProfile.fromJson(data);
      }

      throw const ApiError(
        code: 'UNKNOWN_ERROR',
        message: 'Une erreur est survenue. Veuillez réessayer.',
      );
    } on DioException catch (error) {
      throw _handleDioError(error);
    }
  }

  (String, String)? _resolveNameParts({
    String? firstName,
    String? lastName,
    String? fullName,
  }) {
    final normalizedFirstName = firstName?.trim() ?? '';
    final normalizedLastName = lastName?.trim() ?? '';
    if (normalizedFirstName.isNotEmpty && normalizedLastName.isNotEmpty) {
      return (normalizedFirstName, normalizedLastName);
    }

    final fallbackName = fullName?.trim() ?? '';
    if (fallbackName.isEmpty) {
      return null;
    }

    final parts = fallbackName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length < 2) {
      return null;
    }

    return (parts.first, parts.skip(1).join(' '));
  }

  ApiError _handleDioError(DioException error) {
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
        final details = data['details'];
        final fields = details is Map<String, dynamic> ? details : null;
        return ApiError(
          code: code,
          message:
              data['error']?.toString() ??
              data['message']?.toString() ??
              error.message ??
              'Une erreur est survenue.',
          fields: fields,
        );
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
        message: 'Impossible de se connecter. Vérifiez votre connexion.',
      );
    }

    return ApiError(
      code: 'UNKNOWN_ERROR',
      message: error.message ?? 'Une erreur est survenue.',
    );
  }
}
