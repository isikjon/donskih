import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

const _apiBase = 'https://donskih-cdn.ru/api/v1';

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

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM authorization: ${settings.authorizationStatus}');

    final token = await _messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    _messaging.onTokenRefresh.listen(_registerToken);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
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
        body: jsonEncode({
          'token': fcmToken,
          'platform': platform,
        }),
      );
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('FCM foreground: ${message.notification?.title}');
  }
}
