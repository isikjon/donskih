import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'upload_picker.dart';

const apiBase = 'https://donskih-cdn.ru/api/v1';
const _keyAdminKey = 'admin_content_key';

class AdminApiService {
  static final AdminApiService _instance = AdminApiService._();
  factory AdminApiService() => _instance;
  AdminApiService._();

  SharedPreferences? _prefs;
  String? lastError;

  Future<SharedPreferences> get _sp async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<String?> getAdminKey() async {
    final sp = await _sp;
    return sp.getString(_keyAdminKey);
  }

  Future<void> setAdminKey(String key) async {
    final sp = await _sp;
    await sp.setString(_keyAdminKey, key);
  }

  Future<void> clearAdminKey() async {
    final sp = await _sp;
    await sp.remove(_keyAdminKey);
  }

  Map<String, String> _headers(String? adminKey) {
    final m = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    if (adminKey != null && adminKey.isNotEmpty) {
      m['X-Admin-Key'] = adminKey;
    }
    return m;
  }

  String _errorFromResponse(http.Response resp) {
    if (resp.statusCode == 413) {
      return 'Файл слишком большой для текущего лимита сервера';
    }
    if (resp.statusCode == 504) {
      return 'Сервер не успел обработать видео, попробуйте файл меньше или повторите';
    }
    try {
      final body = jsonDecode(resp.body);
      if (body is Map<String, dynamic>) {
        final detail = body['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        final error = body['error'];
        if (error is String && error.isNotEmpty) return error;
      }
    } catch (_) {}
    return 'HTTP ${resp.statusCode}';
  }

  Future<List<Map<String, dynamic>>?> fetchContentList(
    String? adminKey, {
    String? section,
  }) async {
    lastError = null;
    try {
      var url = '$apiBase/admin/content';
      if (section != null) url += '?section=$section';
      final resp = await http.get(
        Uri.parse(url),
        headers: _headers(adminKey),
      );
      if (resp.statusCode != 200) {
        lastError = _errorFromResponse(resp);
        return null;
      }
      final list = jsonDecode(resp.body) as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  Future<Map<String, dynamic>?> createContent(
    String? adminKey,
    Map<String, dynamic> body,
  ) async {
    lastError = null;
    try {
      final resp = await http.post(
        Uri.parse('$apiBase/admin/content'),
        headers: _headers(adminKey),
        body: jsonEncode(body),
      );
      if (resp.statusCode != 201) {
        lastError = _errorFromResponse(resp);
        return null;
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateContent(
    String? adminKey,
    String id,
    Map<String, dynamic> body,
  ) async {
    lastError = null;
    try {
      final resp = await http.put(
        Uri.parse('$apiBase/admin/content/$id'),
        headers: _headers(adminKey),
        body: jsonEncode(body),
      );
      if (resp.statusCode != 200) {
        lastError = _errorFromResponse(resp);
        return null;
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Users management
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> fetchUsers(
    String? adminKey, {
    int limit = 50,
    int offset = 0,
    String search = '',
  }) async {
    lastError = null;
    try {
      final uri = Uri.parse(
        '$apiBase/admin/users?limit=$limit&offset=$offset&search=${Uri.encodeQueryComponent(search)}',
      );
      final resp = await http.get(uri, headers: _headers(adminKey));
      if (resp.statusCode != 200) {
        lastError = _errorFromResponse(resp);
        return null;
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchUserDetail(
    String? adminKey,
    String userId,
  ) async {
    lastError = null;
    try {
      final resp = await http.get(
        Uri.parse('$apiBase/admin/users/$userId'),
        headers: _headers(adminKey),
      );
      if (resp.statusCode != 200) {
        lastError = _errorFromResponse(resp);
        return null;
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  Future<bool> blockUser(String? adminKey, String userId) async {
    lastError = null;
    try {
      final resp = await http.post(
        Uri.parse('$apiBase/admin/users/$userId/block'),
        headers: _headers(adminKey),
      );
      if (resp.statusCode != 200) {
        lastError = _errorFromResponse(resp);
        return false;
      }
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  Future<bool> unblockUser(String? adminKey, String userId) async {
    lastError = null;
    try {
      final resp = await http.post(
        Uri.parse('$apiBase/admin/users/$userId/unblock'),
        headers: _headers(adminKey),
      );
      if (resp.statusCode != 200) {
        lastError = _errorFromResponse(resp);
        return false;
      }
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Chat moderation
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>?> fetchChatMessages(
    String? adminKey, {
    int limit = 50,
    String? beforeId,
    String? userId,
  }) async {
    lastError = null;
    try {
      var url = '$apiBase/admin/chat/messages?limit=$limit';
      if (beforeId != null) url += '&before_id=$beforeId';
      if (userId != null) url += '&user_id=$userId';
      final resp = await http.get(Uri.parse(url), headers: _headers(adminKey));
      if (resp.statusCode != 200) {
        lastError = _errorFromResponse(resp);
        return null;
      }
      return (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  Future<bool> adminDeleteChatMessage(String? adminKey, String messageId) async {
    lastError = null;
    try {
      final resp = await http.delete(
        Uri.parse('$apiBase/admin/chat/messages/$messageId'),
        headers: _headers(adminKey),
      );
      if (resp.statusCode != 204) {
        lastError = _errorFromResponse(resp);
        return false;
      }
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  // ---------------------------------------------------------------------------

  Future<bool> deleteContent(String? adminKey, String id) async {
    lastError = null;
    try {
      final resp = await http.delete(
        Uri.parse('$apiBase/admin/content/$id'),
        headers: _headers(adminKey),
      );
      if (resp.statusCode != 204) {
        lastError = _errorFromResponse(resp);
      }
      return resp.statusCode == 204;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  Future<Map<String, dynamic>?> uploadVideoBytes(
    String? adminKey, {
    required String filename,
    required List<int> bytes,
    void Function(int sent, int total)? onUploadProgress,
  }) async {
    lastError = null;
    if (adminKey == null || adminKey.isEmpty) {
      lastError = 'Нет ключа администратора';
      return null;
    }

    if (bytes.isEmpty) {
      lastError = 'Файл не прочитан';
      return null;
    }

    try {
      if (kIsWeb) {
        final result = await uploadFileWithProgress(
          url: '$apiBase/admin/content/upload-video',
          fieldName: 'file',
          filename: filename,
          bytes: bytes,
          headers: {
            'X-Admin-Key': adminKey,
            'Accept': 'application/json',
          },
          onProgress: onUploadProgress,
        );
        return result;
      }

      final uri = Uri.parse('$apiBase/admin/content/upload-video');
      final request = http.MultipartRequest('POST', uri);
      request.headers['X-Admin-Key'] = adminKey;
      request.headers['Accept'] = 'application/json';
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

      final client = http.Client();
      try {
        final streamed = await client.send(request);
        final resp = await http.Response.fromStream(streamed);
        if (resp.statusCode != 200) {
          lastError = _errorFromResponse(resp);
          return null;
        }
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } finally {
        client.close();
      }
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  Future<Map<String, dynamic>?> uploadChecklistBytes(
    String? adminKey, {
    required String filename,
    required List<int> bytes,
  }) async {
    lastError = null;
    if (adminKey == null || adminKey.isEmpty) {
      lastError = 'Нет ключа администратора';
      return null;
    }

    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBase/admin/content/upload-checklist'),
      );
      req.headers['X-Admin-Key'] = adminKey;
      req.headers['Accept'] = 'application/json';

      if (bytes.isEmpty) {
        lastError = 'Файл не прочитан';
        return null;
      }
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode != 200) {
        lastError = _errorFromResponse(resp);
        return null;
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }
}
