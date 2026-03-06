import 'package:dio/dio.dart';
import '../../domain/models/offer.dart';
import '../../domain/models/global_offer.dart';
import '../../domain/models/client_offer.dart';
import '../../domain/models/my_offer_item.dart';
import '../../domain/models/api_error.dart';
import '../../domain/repositories/offer_repository.dart';
import '../../core/network/dio_client.dart';

class OfferRepositoryImpl implements OfferRepository {
  OfferRepositoryImpl({
    required DioClient dioClient,
  }) : _dio = dioClient.dio;

  final Dio _dio;

  @override
  Future<List<GlobalOffer>> getGlobalOffers() async {
    return [];
  }

  @override
  Future<List<ClientOffer>> getActiveOffers() async {
    try {
      final response = await _dio.get('/api/v1/offers');
      final data = response.data;
      List<dynamic>? list;
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is List) {
          list = inner;
        }
      }
      if (list == null) return [];
      return list
          .map((e) => ClientOffer.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<RequestActivationResult> requestActivation(String offerId) async {
    try {
      final response = await _dio.post('/api/v1/offers/$offerId/request-activation');
      final data = response.data;
      final map = data is Map<String, dynamic> ? data['data'] as Map<String, dynamic>? ?? data : data as Map<String, dynamic>;
      return RequestActivationResult.fromJson(map);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> cancelActivation(String activationId) async {
    try {
      await _dio.delete('/api/v1/offers/activations/$activationId');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> cancelPendingActivation(String offerId) async {
    try {
      await _dio.delete('/api/v1/offers/$offerId/activation');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<List<MyOfferItem>> getMyOffers() async {
    try {
      final response = await _dio.get('/api/v1/client/offers');
      final data = response.data;
      List<dynamic>? list;
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is List) {
          list = inner;
        }
      }
      if (list == null) return [];
      return list
          .map((e) => MyOfferItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, String>> getActivationStates() async {
    try {
      final response = await _dio.get('/api/v1/client/offers/activation-states');
      final data = response.data;
      final map = data is Map<String, dynamic> ? data['data'] as Map<String, dynamic>? ?? data : data as Map<String, dynamic>?;
      if (map == null) return {};
      return map.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    } on DioException catch (_) {
      return {};
    }
  }

  @override
  Future<List<Offer>> getPrestations(String salonId) async {
    try {
      final response = await _dio.get('/api/v1/salons/$salonId/prestations');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        final list = data['data'] as List<dynamic>;
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