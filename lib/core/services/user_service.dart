import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user.dart';
import 'auth_service.dart';

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
        Uri.parse('$apiBase/users/$userId'),
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
    } catch (_) {}

    return null;
  }
}

