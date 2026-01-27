import 'package:dio/dio.dart';
import '../../domain/models/auth_response.dart';
import '../../domain/models/api_error.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/network/dio_client.dart';

/// Implementation of AuthRepository using Dio
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required DioClient dioClient,
  }) : _dio = dioClient.dio;

  final Dio _dio;

  @override
  Future<AuthResponse> register({
    required String email,
    required String phoneNumber,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/register',
        data: {
          'email': email,
          'phoneNumber': phoneNumber,
          'password': password,
          if (fullName != null) 'fullName': fullName,
        },
      );

      return AuthResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> login({
    String? email,
    String? phoneNumber,
    required String password,
  }) async {
    try {
      final data = <String, dynamic>{
        'password': password,
      };
      
      if (email != null) {
        data['email'] = email;
      } else if (phoneNumber != null) {
        data['phoneNumber'] = phoneNumber;
      }

      final response = await _dio.post(
        '/api/v1/auth/login',
        data: data,
      );

      return AuthResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<User> getCurrentUser() async {
    try {
      final response = await _dio.get('/api/v1/auth/me');
      final data = response.data as Map<String, dynamic>;
      return User.fromJson(data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post(
        '/api/v1/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post(
        '/api/v1/auth/forgot-password',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
  }) async {
    try {
      await _dio.post(
        '/api/v1/auth/reset-password',
        data: {
          'email': email,
          'token': token,
          'newPassword': password,
        },
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Convert DioException to ApiError
  ApiError _handleDioError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map<String, dynamic>) {
        return ApiError.fromErrorResponse(data);
      }
    }

    // Network/timeout errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const ApiError(
        code: 'NETWORK_ERROR',
        message: 'Problème de connexion. Réessayez.',
      );
    }

    return ApiError(
      code: 'UNKNOWN_ERROR',
      message: error.message ?? 'Une erreur est survenue.',
    );
  }
}
