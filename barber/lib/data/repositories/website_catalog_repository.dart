import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/api_error.dart';
import '../../domain/models/barber.dart';
import '../../domain/models/salon.dart';
import '../../domain/repositories/barber_repository.dart';
import '../../domain/repositories/salon_repository.dart';
import '../parsers/website_catalog_parser.dart';

/// Public editorial content comes directly from the same pages clients see.
/// Railway continues to own app accounts, loyalty, and offer activations.
class WebsiteCatalogRepository implements SalonRepository, BarberRepository {
  WebsiteCatalogRepository({
    Dio? dio,
    Uri? siteUrl,
    WebsiteCatalogParser? parser,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 20),
               responseType: ResponseType.plain,
             ),
           ),
       _siteUrl = siteUrl ?? Uri.parse('${AppConfig.publicSiteBaseUrl}/'),
       _parser = parser ?? const WebsiteCatalogParser();

  final Dio _dio;
  final Uri _siteUrl;
  final WebsiteCatalogParser _parser;
  final Map<String, ({DateTime expires, Future<String> response})> _pages = {};

  Future<String> _page(Uri uri) async {
    if (uri.origin != _siteUrl.origin) {
      throw const FormatException('Unexpected website origin.');
    }
    final key = uri.toString();
    final cached = _pages[key];
    if (cached != null && cached.expires.isAfter(DateTime.now()))
      return cached.response;
    final response = _download(uri);
    _pages[key] = (
      expires: DateTime.now().add(const Duration(minutes: 5)),
      response: response,
    );
    try {
      return await response;
    } catch (_) {
      _pages.remove(key);
      rethrow;
    }
  }

  Future<String> _download(Uri uri) async {
    try {
      final response = await _dio.get<String>(
        uri.toString(),
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data;
      if (html == null || !html.contains('<html'))
        throw const FormatException('Empty website page.');
      return html;
    } on DioException {
      throw const ApiError(
        code: 'NETWORK_ERROR',
        message:
            'Impossible de charger le contenu du site. Veuillez réessayer.',
      );
    }
  }

  @override
  Future<List<Salon>> getSalons() async {
    final ids = _parser.salonIds(await _page(_siteUrl));
    if (ids.isEmpty) throw const FormatException('No published salons found.');
    return Future.wait(ids.map(getSalonById));
  }

  @override
  Future<Salon> getSalonById(String id) async {
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(id))
      throw const FormatException('Invalid salon.');
    // Keep .html while resolving relative assets: the website redirects to extensionless URLs.
    final uri = _siteUrl.resolve('pages/$id/salon.html');
    return _parser.salon(id: id, pageUrl: uri, html: await _page(uri));
  }

  Future<List<WebsiteBarberEntry>> _team(Salon salon) async {
    final uri = _siteUrl.resolve('pages/${salon.id}/barbers.html');
    return _parser.barbers(salon: salon, pageUrl: uri, html: await _page(uri));
  }

  @override
  Future<List<Barber>> getBarbers({String? salonId}) async {
    final salons = salonId == null
        ? await getSalons()
        : [await getSalonById(salonId)];
    final teams = await Future.wait(salons.map(_team));
    return teams
        .expand((entries) => entries.map((entry) => entry.barber))
        .toList();
  }

  @override
  Future<Barber> getBarberById(String id) async {
    final salonId = id.split('--').first;
    final team = await _team(await getSalonById(salonId));
    for (final entry in team) {
      if (entry.barber.id != id) continue;
      final uri = entry.profileUrl;
      if (uri == null) return entry.barber;
      return _parser.barberDetail(
        summary: entry.barber,
        pageUrl: uri,
        html: await _page(uri),
      );
    }
    throw const ApiError(code: 'NOT_FOUND', message: 'Coiffeur introuvable.');
  }
}
