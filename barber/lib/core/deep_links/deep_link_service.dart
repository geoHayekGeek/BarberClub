import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

/// Service to handle deep links for password reset
class DeepLinkService {
  StreamSubscription<Uri>? _linkSubscription;
  AppLinks? _appLinks;
  GoRouter? _router;
  bool _initialized = false;

  /// Initialize deep link listeners
  void initialize(GoRouter router) {
    if (_initialized) return;
    _router = router;
    _appLinks = AppLinks();
    _initialized = true;
    _handleInitialLink();
    _handleIncomingLinks();
  }

  /// Handle initial link (when app is opened from a link)
  Future<void> _handleInitialLink() async {
    try {
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        _processDeepLink(initialUri);
      }
    } catch (e) {
      // Ignore errors on initial link
    }
  }

  /// Handle incoming links (when app is already running)
  void _handleIncomingLinks() {
    _linkSubscription = _appLinks!.uriLinkStream.listen(
      (Uri uri) {
        _processDeepLink(uri);
      },
      onError: (err) {
        // Ignore link errors
      },
    );
  }

  /// Process deep link and navigate if valid
  void _processDeepLink(Uri uri) {
    if (_router == null) return;

    try {
      // Check if it's a password reset link
      // Format: barberclub://reset-password?token=XXX&email=YYY
      if (uri.scheme == 'barberclub' && 
          (uri.host == 'reset-password' || uri.path == '/reset-password' || uri.path == 'reset-password') &&
          uri.queryParameters.containsKey('token') &&
          uri.queryParameters.containsKey('email')) {
        
        final token = uri.queryParameters['token']!;
        final email = uri.queryParameters['email']!;
        
        // Validate token and email are not empty
        if (token.isNotEmpty && email.isNotEmpty) {
          // Navigate to reset password screen
          _router!.go('/reset-password?token=$token&email=${Uri.encodeComponent(email)}');
        }
      }
    } catch (e) {
      // Invalid link format, ignore
    }
  }

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
    _router = null;
  }
}
