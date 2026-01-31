import 'package:dio/dio.dart';
import '../../domain/models/salon.dart';
import '../../domain/models/api_error.dart';
import '../../domain/repositories/salon_repository.dart';
import '../../core/network/dio_client.dart';

/// Implementation of SalonRepository using Dio.
class SalonRepositoryImpl implements SalonRepository {
  SalonRepositoryImpl({
    required DioClient dioClient,
  }) : _dio = dioClient.dio;

  final Dio _dio;

  @override
  Future<List<Salon>> getSalons() async {
    try {
      final response = await _dio.get('/api/v1/salons');
      final data = response.data;
      // Backend returns { data: salons }
      List<dynamic> list = const [];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        if (data['data'] is List) {
          list = data['data'] as List;
        } else if (data['salons'] is List) {
          list = data['salons'] as List;
        }
      }
      return list
          .map((e) => Salon.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Salon> getSalonById(String id) async {
    try {
      final response = await _dio.get('/api/v1/salons/$id');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        // Backend returns { data: salon }
        final salonData = data['data'] as Map<String, dynamic>? ??
            data['salon'] as Map<String, dynamic>? ??
            data;
        return Salon.fromJson(salonData);
      }
      throw const ApiError(
        code: 'UNKNOWN_ERROR',
        message: 'Une erreur est survenue. Veuillez réessayer.',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiError _handleDioError(DioException error) {
    if (error.response != null) {
      if (error.response!.statusCode == 404) {
        return const ApiError(
          code: 'NOT_FOUND',
          message: 'Salon introuvable.',
        );
      }
      final data = error.response!.data;
      if (data is Map<String, dynamic>) {
        return ApiError.fromErrorResponse(data);
      }
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
      message: error.message ?? 'Une erreur est survenue. Veuillez réessayer.',
    );
  }
}
