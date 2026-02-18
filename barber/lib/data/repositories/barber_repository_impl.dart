import 'package:dio/dio.dart';
import '../../domain/models/barber.dart';
import '../../domain/models/api_error.dart';
import '../../domain/repositories/barber_repository.dart';
import '../../core/network/dio_client.dart';

/// Implementation of BarberRepository using Dio.
class BarberRepositoryImpl implements BarberRepository {
  BarberRepositoryImpl({
    required DioClient dioClient,
  }) : _dio = dioClient.dio;

  final Dio _dio;

  @override
  Future<List<Barber>> getBarbers({String? salonId}) async {
    try {
      final queryParams = salonId != null ? {'salonId': salonId} : null;
      if (salonId != null) {
        // ignore: avoid_print
        print('BarberRepository: getBarbers salonId=$salonId');
      }
      final response = await _dio.get(
        '/api/v1/barbers',
        queryParameters: queryParams,
      );
      // ignore: avoid_print
      print('BarberRepository: response.data=${response.data}');
      final data = response.data;
      List<dynamic> list = const [];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        if (data['data'] is List) {
          list = data['data'] as List;
        } else if (data['barbers'] is List) {
          list = data['barbers'] as List;
        }
      }
      return list
          .map((e) => Barber.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Barber> getBarberById(String id) async {
    try {
      final response = await _dio.get('/api/v1/barbers/$id');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final barberData = data['data'] as Map<String, dynamic>? ??
            data['barber'] as Map<String, dynamic>? ??
            data;
        return Barber.fromJson(barberData);
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
          message: 'Coiffeur introuvable.',
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
        message: 'Impossible de charger les coiffeurs.',
      );
    }

    return ApiError(
      code: 'UNKNOWN_ERROR',
      message: error.message ?? 'Une erreur est survenue. Veuillez réessayer.',
    );
  }
}
