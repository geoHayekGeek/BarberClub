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
      // Wait a bit for router to be ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        // Additional delay to ensure router is ready
        await Future.delayed(const Duration(milliseconds: 300));
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
  /// Note: Password reset no longer uses deep links (OTP flow instead)
  void _processDeepLink(Uri uri) {
    if (_router == null) {
      // Retry after a short delay if router not ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_router != null) {
          _processDeepLink(uri);
        }
      });
      return;
    }

    // Password reset deep links (barberclub://reset-password) have been removed.
    // Reset flow now uses OTP code entered in-app.
    // Add other deep link handlers here as needed.
  }

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
    _router = null;
  }
}
