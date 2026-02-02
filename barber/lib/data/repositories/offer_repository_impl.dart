import 'package:dio/dio.dart';
import '../../domain/models/offer.dart';
import '../../domain/models/api_error.dart';
import '../../domain/repositories/offer_repository.dart';
import '../../core/network/dio_client.dart';

class OfferRepositoryImpl implements OfferRepository {
  OfferRepositoryImpl({
    required DioClient dioClient,
  }) : _dio = dioClient.dio;

  final Dio _dio;

  @override
  Future<List<Offer>> getOffers({String? salonId}) async {
    try {
      // Pass the salonId as a query parameter to the backend
      final response = await _dio.get(
        '/api/v1/offers',
        queryParameters: salonId != null ? {'salonId': salonId} : null,
      );
      
      final Map<String, dynamic> responseData = response.data;

      // Unpack the nested data: { "data": { "items": [...] } }
      if (responseData['data'] != null && responseData['data']['items'] is List) {
        final List<dynamic> list = responseData['data']['items'];
        return list
            .map((e) => Offer.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      
      return []; 
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Offer> getOfferById(String id) async {
    try {
      final response = await _dio.get('/api/v1/offers/$id');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final offerData = data['data'] as Map<String, dynamic>? ?? data;
        return Offer.fromJson(offerData);
      }
      throw const ApiError(
        code: 'UNKNOWN_ERROR',
        message: 'Une erreur est survenue.',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiError _handleDioError(DioException error) {
    if (error.response?.statusCode == 404) {
      return const ApiError(code: 'NOT_FOUND', message: 'Offre introuvable.');
    }
    return const ApiError(code: 'NETWORK_ERROR', message: 'Erreur de connexion.');
  }
}