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
  void Function(String type)? _onLoyaltyEvent;
  static bool _initialized = false;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initialize Firebase Messaging: request permissions (iOS) and background handler
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(initSettings);

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
    } catch (e) {
      // Silently ignore
    }
  }

  /// Setup foreground and opened-from-notification handlers
  void setupListeners(void Function(String type) onLoyaltyEvent) {
    if (!_initialized) return;
    _onLoyaltyEvent = onLoyaltyEvent;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(
          title: notification.title ?? 'Notification',
          body: notification.body ?? '',
        );
      }
      
      final data = message.data;
      final type = data['type'] as String?;
      if (type != null && (type == 'LOYALTY_POINT' || type == 'LOYALTY_REWARD')) {
        _onLoyaltyEvent?.call(type);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final data = message.data;
      final type = data['type'] as String?;
      if (type != null && (type == 'LOYALTY_POINT' || type == 'LOYALTY_REWARD')) {
        _onLoyaltyEvent?.call(type);
      }
    });
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
  }
}
