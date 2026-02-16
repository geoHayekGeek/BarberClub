import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initialize Firebase Messaging: request permissions (iOS) and background handler
  static Future<void> initialize() async {
    // #region agent log
    debugPrint('[FCM LOG] fcm_service.dart:22 - FCM initialize called');
    // #endregion
    
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(initSettings);
    
    debugPrint('[FCM LOG] Local notifications initialized');
    
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    // #region agent log
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    debugPrint('[FCM LOG] fcm_service.dart:28 - FCM permission requested - authStatus=${settings.authorizationStatus}, alert=${settings.alert}, badge=${settings.badge}, sound=${settings.sound}');
    // #endregion
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _initialized = true;
  }

  /// Register FCM token with backend (call after login success)
  Future<void> registerWithBackend() async {
    try {
      // #region agent log
      debugPrint('[FCM LOG] fcm_service.dart:34 - FCM getToken called');
      // #endregion
      final token = await FirebaseMessaging.instance.getToken();
      // #region agent log
      debugPrint('[FCM LOG] fcm_service.dart:37 - FCM token retrieved: exists=${token != null}, length=${token?.length ?? 0}, preview=${token?.substring(0, token!.length > 20 ? 20 : token.length)}');
      // #endregion
      if (token == null || token.isEmpty) return;
      // #region agent log
      debugPrint('[FCM LOG] fcm_service.dart:41 - Calling backend to save token');
      // #endregion
      await _dio.post(
        '/api/v1/users/device-token',
        data: {'token': token},
      );
      // #region agent log
      debugPrint('[FCM LOG] fcm_service.dart:47 - Backend token save SUCCESS');
      // #endregion
    } catch (e) {
      // #region agent log
      debugPrint('[FCM LOG] fcm_service.dart:51 - registerWithBackend FAILED: $e');
      // #endregion
    }
  }

  void _log(String location, String message, Map<String, dynamic> data, String hypothesisId) {
    debugPrint('[FCM LOG] $location - $message - data: $data - hypothesis: $hypothesisId');
  }

  /// Setup foreground and opened-from-notification handlers
  void setupListeners(VoidCallback onLoyaltyPoint) {
    if (!_initialized) return;
    _onLoyaltyPoint = onLoyaltyPoint;

    // #region agent log
    debugPrint('[FCM LOG] fcm_service.dart:50 - Setting up FCM listeners');
    // #endregion

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // #region agent log
      debugPrint('[FCM LOG] fcm_service.dart:55 - FCM onMessage received (FOREGROUND) - hasNotif=${message.notification != null}, title="${message.notification?.title}", body="${message.notification?.body}", dataType="${message.data['type']}", allDataKeys=${message.data.keys.toList()}');
      // #endregion
      
      // Show notification manually when app is in foreground
      final notification = message.notification;
      if (notification != null) {
        debugPrint('[FCM LOG] Showing local notification for foreground message');
        _showLocalNotification(
          title: notification.title ?? 'Notification',
          body: notification.body ?? '',
        );
      }
      
      final data = message.data;
      if (data['type'] == 'LOYALTY_POINT') {
        // #region agent log
        debugPrint('[FCM LOG] fcm_service.dart:65 - LOYALTY_POINT detected, calling callback');
        // #endregion
        _onLoyaltyPoint?.call();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // #region agent log
      debugPrint('[FCM LOG] fcm_service.dart:73 - FCM onMessageOpenedApp (from background) - dataType="${message.data['type']}"');
      // #endregion
      final data = message.data;
      if (data['type'] == 'LOYALTY_POINT') {
        _onLoyaltyPoint?.call();
      }
    });
    
    // #region agent log
    debugPrint('[FCM LOG] fcm_service.dart:83 - FCM listeners setup complete');
    // #endregion
  }

  Future<void> _showLocalNotification({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'Notifications importantes',
      channelDescription: 'Notifications pour les points de fidélité',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
    debugPrint('[FCM LOG] Local notification displayed: $title');
  }
}
