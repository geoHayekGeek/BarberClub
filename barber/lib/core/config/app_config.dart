/// Application configuration
/// Supports API_BASE_URL via --dart-define
class AppConfig {
  AppConfig._();

  static const String _defaultApiBaseUrl =
      'https://barberclub-production-d46a.up.railway.app';
  static const String _defaultReservationApiBaseUrl =
      'https://api.barberclub-grenoble.fr/api';
  static const String _defaultPublicSiteBaseUrl =
      'https://barberclub-grenoble.fr';

  /// API base URL from --dart-define or default
  static String get apiBaseUrl {
    const String fromDefine = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: _defaultApiBaseUrl,
    );
    final normalized = fromDefine.trim();
    return normalized.isEmpty ? _defaultApiBaseUrl : normalized;
  }

  /// Reservation API base URL from --dart-define or default.
  static String get reservationApiBaseUrl {
    const String fromDefine = String.fromEnvironment(
      'RESERVATION_API_BASE_URL',
      defaultValue: _defaultReservationApiBaseUrl,
    );

    final normalized = fromDefine.trim();
    return normalized.isEmpty ? _defaultReservationApiBaseUrl : normalized;
  }

  /// Public site base URL used for barber photos and other website assets.
  static String get publicSiteBaseUrl {
    const String fromDefine = String.fromEnvironment(
      'PUBLIC_SITE_BASE_URL',
      defaultValue: _defaultPublicSiteBaseUrl,
    );
    final normalized = fromDefine.trim();
    return normalized.isEmpty ? _defaultPublicSiteBaseUrl : normalized;
  }

  /// API timeout in milliseconds
  static const int apiTimeoutMs = 30000;

  /// Refresh token endpoint path
  static const String refreshTokenPath = '/api/v1/auth/refresh';

  /// Resolves an image URL: if relative (starts with /), prepends apiBaseUrl.
  /// Returns null if [url] is null or empty.
  /// Appends ?v=1 to relative URLs to bust stale cache (e.g. from 404 before backend had images).
  static String? resolveImageUrl(String? url) {
    return _resolveAsset(apiBaseUrl, url);
  }

  /// Resolves a website asset URL from the public site domain.
  static String? resolvePublicAssetUrl(String? url) {
    return _resolveAsset(publicSiteBaseUrl, url);
  }

  static String? _resolveAsset(String baseUrl, String? value) {
    final url = value?.trim();
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.hasScheme) {
      return ['http', 'https', 'data'].contains(uri.scheme)
          ? uri.toString()
          : null;
    }
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    final resolved = base.resolveUri(uri);
    if (uri.hasAuthority) return resolved.toString();
    return resolved
        .replace(queryParameters: {'v': '1', ...resolved.queryParameters})
        .toString();
  }

  /// Reservation portraits are shorthand paths within the public image folder.
  static String? resolveReservationBarberPhotoUrl(String? value) {
    final url = value?.trim();
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.hasScheme || uri.hasAuthority) return resolvePublicAssetUrl(url);
    final path = uri.path.replaceFirst(RegExp(r'^/+'), '');
    final assetPath = path.startsWith('assets/images/')
        ? path
        : path.startsWith('images/')
        ? 'assets/$path'
        : 'assets/images/$path';
    return resolvePublicAssetUrl(uri.replace(path: '/$assetPath').toString());
  }
}
