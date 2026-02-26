import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const apiBase = 'https://donskih-cdn.ru/api/v1';

class AuthService {
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserJson = 'user_json';
  static const _keySubJson = 'subscription_json';
  static const _keyIsBlocked = 'is_blocked';

  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  SharedPreferences? _prefs;
  Map<String, dynamic>? _cachedUser;

  Future<SharedPreferences> get _sp async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<bool> get isLoggedIn async {
    final sp = await _sp;
    return sp.getString(_keyAccessToken) != null;
  }

  Future<bool> get isBlocked async {
    final sp = await _sp;
    return sp.getBool(_keyIsBlocked) ?? false;
  }

  Future<void> _setBlocked(bool value) async {
    final sp = await _sp;
    await sp.setBool(_keyIsBlocked, value);
  }

  Future<String?> get accessToken async {
    final sp = await _sp;
    return sp.getString(_keyAccessToken);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final sp = await _sp;
    await sp.setString(_keyAccessToken, accessToken);
    await sp.setString(_keyRefreshToken, refreshToken);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final sp = await _sp;
    await sp.setString(_keyUserJson, jsonEncode(user));
    _cachedUser = user;
  }

  Future<Map<String, dynamic>?> getUser() async {
    if (_cachedUser != null) return _cachedUser;
    final sp = await _sp;
    final json = sp.getString(_keyUserJson);
    if (json == null) return null;
    _cachedUser = jsonDecode(json);
    return _cachedUser;
  }

  Future<Map<String, dynamic>?> fetchProfile() async {
    final token = await accessToken;
    if (token == null) return null;

    try {
      final resp = await http.get(
        Uri.parse('$apiBase/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        await _setBlocked(false);
        final user = jsonDecode(resp.body) as Map<String, dynamic>;
        await saveUser(user);
        return user;
      }

      if (resp.statusCode == 403) {
        await _setBlocked(true);
        return null;
      }

      if (resp.statusCode == 401) {
        final refreshed = await _refreshTokens();
        if (refreshed) return fetchProfile();
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? _cachedSub;

  Future<void> saveSubscription(Map<String, dynamic> sub) async {
    final sp = await _sp;
    await sp.setString(_keySubJson, jsonEncode(sub));
    _cachedSub = sub;
  }

  Future<Map<String, dynamic>?> getSubscription() async {
    if (_cachedSub != null) return _cachedSub;
    final sp = await _sp;
    final json = sp.getString(_keySubJson);
    if (json == null) return null;
    _cachedSub = jsonDecode(json);
    return _cachedSub;
  }

  Future<Map<String, dynamic>?> fetchSubscription() async {
    final token = await accessToken;
    if (token == null) return null;

    try {
      final resp = await http.get(
        Uri.parse('$apiBase/subscription/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        await saveSubscription(data);
        return data;
      }

      if (resp.statusCode == 401) {
        final refreshed = await _refreshTokens();
        if (refreshed) return fetchSubscription();
      }
    } catch (_) {}
    return null;
  }

  Future<bool> refreshTokens() async => _refreshTokens();

  Future<bool> _refreshTokens() async {
    final sp = await _sp;
    final rt = sp.getString(_keyRefreshToken);
    if (rt == null) return false;

    try {
      final resp = await http.post(
        Uri.parse('$apiBase/auth/telegram/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': rt}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        await saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );
        return true;
      }
    } catch (_) {}

    return false;
  }

  Future<void> logout() async {
    final token = await accessToken;
    if (token != null) {
      try {
        await http.post(
          Uri.parse('$apiBase/auth/telegram/logout'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } catch (_) {}
    }

    final sp = await _sp;
    await sp.remove(_keyAccessToken);
    await sp.remove(_keyRefreshToken);
    await sp.remove(_keyUserJson);
    await sp.remove(_keySubJson);
    await sp.remove(_keyIsBlocked);
    _cachedUser = null;
    _cachedSub = null;
  }
}
