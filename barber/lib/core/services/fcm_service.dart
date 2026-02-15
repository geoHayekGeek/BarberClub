import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../network/dio_client.dart';

/// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// FCM service for push notifications and loyalty reward handling
class FcmService {
  FcmService({required DioClient dioClient}) : _dio = dioClient.dio;

  final dynamic _dio;
  VoidCallback? _onLoyaltyPoint;
  static bool _initialized = false;

  /// Initialize Firebase Messaging: request permissions (iOS) and background handler
  static Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _initialized = true;
  }

  /// Register FCM token with backend (call after login success)
  Future<void> registerWithBackend() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _dio.post(
        '/api/v1/users/device-token',
        data: {'token': token},
      );
    } catch (_) {
      // Silently ignore
    }
  }

  /// Setup foreground and opened-from-notification handlers
  void setupListeners(VoidCallback onLoyaltyPoint) {
    if (!_initialized) return;
    _onLoyaltyPoint = onLoyaltyPoint;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      if (data['type'] == 'LOYALTY_POINT') {
        _onLoyaltyPoint?.call();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final data = message.data;
      if (data['type'] == 'LOYALTY_POINT') {
        _onLoyaltyPoint?.call();
      }
    });
  }
}
