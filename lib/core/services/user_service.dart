import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import 'auth_service.dart';

const _apiBase = 'https://donskih-cdn.ru/api/v1';

class UserService {
  static final UserService _instance = UserService._();
  factory UserService() => _instance;
  UserService._();

  final _auth = AuthService();

  Future<User?> fetchUserById(String userId) async {
    final token = await _auth.accessToken;
    if (token == null) return null;

    try {
      final resp = await http.get(
        Uri.parse('$_apiBase/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        return User.fromPublicJson(json);
      }

      if (resp.statusCode == 401) {
        final ok = await _auth.refreshTokens();
        if (ok) return fetchUserById(userId);
      }

      if (kDebugMode && resp.statusCode != 200) {
        debugPrint('UserService.fetchUserById $userId => ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('UserService.fetchUserById error: $e');
    }

    return null;
  }
}

