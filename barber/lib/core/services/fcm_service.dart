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
      // #region agent log
      fetch('http://127.0.0.1:7242/ingest/63b71ee3-5927-4ca9-971f-9e0480755780',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'fcm_service.dart:34',message:'FCM getToken called',data:{},timestamp:Date.now(),hypothesisId:'D'})}).catch(()=>{});
      // #endregion
      final token = await FirebaseMessaging.instance.getToken();
      // #region agent log
      fetch('http://127.0.0.1:7242/ingest/63b71ee3-5927-4ca9-971f-9e0480755780',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'fcm_service.dart:35',message:'FCM token retrieved',data:{tokenExists:token!=null,tokenLength:token?.length??0,tokenPreview:token?.substring(0,20)??"null"},timestamp:Date.now(),hypothesisId:'D'})}).catch(()=>{});
      // #endregion
      if (token == null || token.isEmpty) return;
      // #region agent log
      fetch('http://127.0.0.1:7242/ingest/63b71ee3-5927-4ca9-971f-9e0480755780',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'fcm_service.dart:38',message:'Calling backend to save token',data:{endpoint:'/api/v1/users/device-token'},timestamp:Date.now(),hypothesisId:'B'})}).catch(()=>{});
      // #endregion
      await _dio.post(
        '/api/v1/users/device-token',
        data: {'token': token},
      );
      // #region agent log
      fetch('http://127.0.0.1:7242/ingest/63b71ee3-5927-4ca9-971f-9e0480755780',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'fcm_service.dart:42',message:'Backend token save SUCCESS',data:{},timestamp:Date.now(),hypothesisId:'B'})}).catch(()=>{});
      // #endregion
    } catch (e) {
      // #region agent log
      fetch('http://127.0.0.1:7242/ingest/63b71ee3-5927-4ca9-971f-9e0480755780',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'fcm_service.dart:44',message:'registerWithBackend FAILED',data:{error:e.toString()},timestamp:Date.now(),hypothesisId:'B'})}).catch(()=>{});
      // #endregion
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
