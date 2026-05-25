import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

  final Dio _dio;
  void Function(String type, [Map<String, String>? data])? _onLoyaltyEvent;
  static bool _initialized = false;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _lastRegisteredToken;

  static void _log(String message) {
    debugPrint('[FCM] $message');
  }

  /// Initialize Firebase Messaging: request permissions (iOS) and background handler
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(initSettings);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _log('Permission status: ${settings.authorizationStatus.name}');

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
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
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _log('Notification permission denied. Skipping FCM registration.');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        _log('No FCM token returned from device.');
        return;
      }

      await _registerToken(token);

      _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
        (refreshedToken) {
          unawaited(_registerToken(refreshedToken));
        },
        onError: (Object error, StackTrace stackTrace) {
          _log('Token refresh stream failed: $error');
        },
      );
    } catch (e) {
      _log('Failed to register FCM token with backend: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    if (token.isEmpty || token == _lastRegisteredToken) return;

    await _dio.post(
      '/api/v1/users/device-token',
      data: {'token': token},
    );
    _lastRegisteredToken = token;
    _log('FCM token registered with backend.');
  }

  /// Setup foreground and opened-from-notification handlers
  void setupListeners(void Function(String type, [Map<String, String>? data]) onLoyaltyEvent) {
    if (!_initialized) return;
    _onLoyaltyEvent = onLoyaltyEvent;

    unawaited(() async {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage == null) return;
      _handleOpenedMessage(initialMessage);
    }());

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      final type = data['type'] as String?;

      if (type == 'LOYALTY_EARN') {
        _onLoyaltyEvent?.call(type!, Map<String, String>.from(data));
        return;
      }
      if (type == 'LOYALTY_REDEEM') {
        _onLoyaltyEvent?.call(type!, Map<String, String>.from(data));
        return;
      }

      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(
          title: notification.title ?? 'Notification',
          body: notification.body ?? '',
        );
      }

      if (type != null && (type == 'LOYALTY_POINT' || type == 'LOYALTY_REWARD')) {
        _onLoyaltyEvent?.call(type);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    if (type == 'LOYALTY_EARN') {
      _onLoyaltyEvent?.call(type!, Map<String, String>.from(data));
      return;
    }
    if (type == 'LOYALTY_REDEEM') {
      _onLoyaltyEvent?.call(type!, Map<String, String>.from(data));
      return;
    }
    if (type != null && (type == 'LOYALTY_POINT' || type == 'LOYALTY_REWARD')) {
      _onLoyaltyEvent?.call(type);
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
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
