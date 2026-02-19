/// Application configuration
/// Supports API_BASE_URL via --dart-define
class AppConfig {
  AppConfig._();
  
  // static const String _defaultApiBaseUrl = 'http://10.0.2.2:3000';
  static const String _defaultApiBaseUrl = 'https://barberclub-production-a6ca.up.railway.app';

  /// API base URL from --dart-define or default
  static String get apiBaseUrl {
    const String fromDefine = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: _defaultApiBaseUrl,
    );
    return fromDefine;
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
}
