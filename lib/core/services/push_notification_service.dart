import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'notification_prefs_service.dart';

const _apiBase = 'https://donskih-cdn.ru/api/v1';

/// Android notification channel for high-importance push notifications.
const _androidChannel = AndroidNotificationChannel(
  'donskih_push_channel',
  'Уведомления',
  description: 'Push-уведомления от приложения Макияж для себя',
  importance: Importance.high,
  playSound: true,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

/// Must be top-level — called by Firebase in a separate isolate when app is terminated/background.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint(
      '[PUSH-DIAG] FCM background handler: ${message.notification?.title}');
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

    debugPrint('[PUSH-DIAG] ===== Push Notification Service init =====');

    await _initLocalNotifications();

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
          '[PUSH-DIAG] Authorization status: ${settings.authorizationStatus}');
      debugPrint('[PUSH-DIAG] Alert setting: ${settings.alert}');
      debugPrint('[PUSH-DIAG] Sound setting: ${settings.sound}');
      debugPrint('[PUSH-DIAG] Badge setting: ${settings.badge}');
    } catch (e) {
      debugPrint('[PUSH-DIAG] requestPermission FAILED: $e');
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _messaging.onTokenRefresh.listen((token) {
      debugPrint('[PUSH-DIAG] Token REFRESHED: ${token.substring(0, 12)}...');
      _registerToken(token);
    });
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _onNotificationTap(initialMessage);
    }

    if (!kIsWeb && Platform.isIOS) {
      try {
        final apnsToken = await _messaging.getAPNSToken();
        debugPrint(
            '[PUSH-DIAG] APNs token: ${apnsToken ?? "NULL — push WILL NOT WORK!"}');
        if (apnsToken == null) {
          debugPrint(
              '[PUSH-DIAG] ⚠️  APNs token is null. Retrying in 3 seconds...');
          await Future.delayed(const Duration(seconds: 3));
          final retryApns = await _messaging.getAPNSToken();
          debugPrint(
              '[PUSH-DIAG] APNs token (retry): ${retryApns ?? "STILL NULL"}');
        }
      } catch (e) {
        debugPrint('[PUSH-DIAG] getAPNSToken error: $e');
      }
    }

    try {
      final token = await _messaging.getToken();
      debugPrint(
          '[PUSH-DIAG] FCM token: ${token != null ? '${token.substring(0, 12)}...' : 'NULL'}');
      if (token != null) {
        await _registerToken(token);
      } else {
        debugPrint('[PUSH-DIAG] ⚠️  FCM token is NULL — no push possible');
      }
    } catch (e) {
      debugPrint('[PUSH-DIAG] getToken FAILED: $e');
    }

    debugPrint('[PUSH-DIAG] ===== Push init complete =====');
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
    if (accessToken == null) {
      debugPrint('[PUSH-DIAG] _registerToken: no access token, skip');
      return;
    }

    final platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');

    debugPrint(
        '[PUSH-DIAG] Registering token=${fcmToken.substring(0, 12)}... platform=$platform');

    try {
      final resp = await http.post(
        Uri.parse('$_apiBase/devices/register'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': fcmToken, 'platform': platform}),
      );
      debugPrint(
          '[PUSH-DIAG] Register response: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      debugPrint('[PUSH-DIAG] Register FAILED: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    debugPrint('[PUSH-DIAG] FOREGROUND message received: '
        'title=${notification?.title}, body=${notification?.body}, '
        'data=${message.data}, from=${message.from}');
    if (notification == null) return;

    final pushType = message.data['type'] as String? ?? 'admin';
    NotificationPrefsService().isTypeEnabled(pushType).then((allowed) {
      if (!allowed) {
        debugPrint(
            '[PUSH-DIAG] Notification type=$pushType suppressed by user prefs');
        return;
      }
      _showLocalNotification(notification, message);
    });
  }

  void _showLocalNotification(
      RemoteNotification notification, RemoteMessage message) {
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
          icon:
              message.notification?.android?.smallIcon ?? '@mipmap/ic_launcher',
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
