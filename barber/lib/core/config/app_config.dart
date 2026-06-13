/// Application configuration
/// Supports API_BASE_URL via --dart-define
class AppConfig {
  AppConfig._();

  static const String _defaultApiBaseUrl = 'https://barberclub-production-d46a.up.railway.app';
  static const String _defaultReservationApiBaseUrl = 'https://api.barberclub-grenoble.fr/api';
  static const String _defaultPublicSiteBaseUrl = 'https://barberclub-grenoble.fr';

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
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/';
    final path = url.startsWith('/') ? url.substring(1) : url;
    return '$base$path?v=1';
  }

  /// Resolves a website asset URL from the public site domain.
  static String? resolvePublicAssetUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = publicSiteBaseUrl.endsWith('/')
        ? publicSiteBaseUrl
        : '$publicSiteBaseUrl/';
    final path = url.startsWith('/') ? url.substring(1) : url;
    return '$base$path?v=1';
  }
}
