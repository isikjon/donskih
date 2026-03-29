import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

const _apiBase = 'https://donskih-cdn.ru/api/v1';

/// Android notification channel for high-importance push notifications.
const _androidChannel = AndroidNotificationChannel(
  'donskih_push_channel',
  'Уведомления Donskih',
  description: 'Push-уведомления от приложения Donskih',
  importance: Importance.high,
  playSound: true,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

/// Must be top-level — called by Firebase in a separate isolate when app is terminated/background.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.notification?.title}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  final _auth = AuthService();
  final _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    await _initLocalNotifications();

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM authorization: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('FCM requestPermission failed: $e');
    }

    // Show notifications when app is in foreground on iOS.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _messaging.onTokenRefresh.listen(_registerToken);
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Handle notification tap when app was in background.
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    // Handle notification tap when app was terminated.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _onNotificationTap(initialMessage);
    }

    try {
      final token = await _messaging.getToken();
      if (token != null) await _registerToken(token);
    } catch (e) {
      debugPrint('FCM getToken failed (normal on simulator): $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Local notification tapped: ${details.payload}');
      },
    );

    // Create channel for Android 8.0+
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> registerCurrentToken() async {
    if (kIsWeb) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) await _registerToken(token);
    } catch (e) {
      debugPrint('FCM registerCurrentToken failed: $e');
    }
  }

  Future<void> _registerToken(String fcmToken) async {
    final accessToken = await _auth.accessToken;
    if (accessToken == null) return;

    final platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');

    try {
      await http.post(
        Uri.parse('$_apiBase/devices/register'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': fcmToken, 'platform': platform}),
      );
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  /// Called when a push arrives while the app is open (foreground).
  /// On Android FCM does not auto-show the notification UI — we do it manually.
  /// On iOS setForegroundNotificationPresentationOptions handles it natively,
  /// but we still show a local notification so Android works identically.
  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: message.notification?.android?.smallIcon ?? '@mipmap/ic_launcher',
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped, data: ${message.data}');
    // TODO: navigate to specific screen based on message.data if needed
  }
}
