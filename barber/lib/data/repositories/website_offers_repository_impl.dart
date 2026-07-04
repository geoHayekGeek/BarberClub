import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/api_error.dart';
import '../../domain/models/website_offers_page_data.dart';
import '../../domain/repositories/website_offers_repository.dart';
import '../parsers/website_offers_page_parser.dart';

class WebsiteOffersRepositoryImpl implements WebsiteOffersRepository {
  WebsiteOffersRepositoryImpl({
    Dio? siteDio,
    WebsiteOffersPageParser? parser,
  })  : _siteDio = siteDio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.publicSiteBaseUrl,
                connectTimeout: const Duration(milliseconds: 30000),
                receiveTimeout: const Duration(milliseconds: 30000),
                sendTimeout: const Duration(milliseconds: 30000),
                responseType: ResponseType.plain,
                headers: const {
                  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                },
              ),
            ),
        _parser = parser ?? const WebsiteOffersPageParser();

  final Dio _siteDio;
  final WebsiteOffersPageParser _parser;

  @override
  Future<WebsiteOffersPageData> loadOffersPage({
    required String salonId,
  }) async {
    final normalizedSalonId = _normalizeSalonId(salonId);
    final pageUrl = Uri.parse(
      '${AppConfig.publicSiteBaseUrl}/pages/$normalizedSalonId/offres.html',
    );

    try {
      final response = await _siteDio.get<String>(
        '/pages/$normalizedSalonId/offres.html',
      );
      final html = response.data ?? '';
      if (html.trim().isEmpty) {
        return _fallback(normalizedSalonId, pageUrl);
      }

      return _parser.parse(
        salonId: normalizedSalonId,
        pageUrl: pageUrl,
        html: html,
      );
    } catch (_) {
      return _fallback(normalizedSalonId, pageUrl);
    }
  }

  @override
  Future<String> subscribeToEventAlert({
    required WebsiteAlertConfig config,
    required String email,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: const Duration(milliseconds: 30000),
        receiveTimeout: const Duration(milliseconds: 30000),
        sendTimeout: const Duration(milliseconds: 30000),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/event-alerts',
        data: {
          'email': email,
          'event_name': config.eventName,
          'salon_id': config.salonId,
        },
      );

      final data = response.data;
      if (data != null) {
        final message = data['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return message.trim();
        }
      }

      return config.successMessage;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;
      final responseMessage = responseData is Map<String, dynamic>
          ? responseData['error']?.toString()
          : null;

      throw ApiError(
        code: statusCode == 400 ? 'VALIDATION_ERROR' : 'NETWORK_ERROR',
        message: responseMessage?.trim().isNotEmpty == true
            ? responseMessage!.trim()
            : statusCode == 400
                ? 'Veuillez vérifier les informations saisies.'
                : 'Impossible de contacter le site.',
      );
    }
  }

  WebsiteOffersPageData _fallback(String salonId, Uri pageUrl) {
    switch (salonId) {
      case 'meylan':
        return WebsiteOffersPageData.fallbackMeylan(pageUrl);
      case 'grenoble':
      default:
        return WebsiteOffersPageData.fallbackGrenoble(pageUrl);
    }
  }

  String _normalizeSalonId(String salonId) {
    final normalized = salonId.trim().toLowerCase();
    switch (normalized) {
      case 'meylan':
      case 'grenoble':
        return normalized;
      default:
        return 'grenoble';
    }
  }
}
