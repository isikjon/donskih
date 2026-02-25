import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/chat_message.dart';
import 'auth_service.dart';

const _wsBase = 'wss://donskih-cdn.ru/api/v1/chat/ws';
const _httpBase = 'https://donskih-cdn.ru/api/v1/chat';

class ChatService {
  static final ChatService _instance = ChatService._();
  factory ChatService() => _instance;
  ChatService._();

  final _auth = AuthService();
  final _controller = StreamController<List<ChatMessage>>.broadcast();
  final List<ChatMessage> _messages = [];

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _connected = false;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  String? _currentUserId;

  Stream<List<ChatMessage>> get stream => _controller.stream;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isConnected => _connected;

  // ---------------------------------------------------------------------------
  // Connection lifecycle
  // ---------------------------------------------------------------------------

  Future<void> connect() async {
    if (_connected) return;

    final token = await _auth.accessToken;
    if (token == null) return;

    final user = await _auth.getUser();
    _currentUserId = user?['id'] as String?;

    await _loadHistory();
    _openSocket(token);
  }

  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _connected = false;
  }

  void _openSocket(String token) {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$_wsBase?token=$token'),
      );
      _connected = true;

      _sub = _channel!.stream.listen(
        _onData,
        onDone: _onDone,
        onError: _onError,
        cancelOnError: false,
      );

      _startPing();
    } catch (e) {
      debugPrint('ChatService: connect error: $e');
      _scheduleReconnect();
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      try {
        _channel?.sink.add('ping');
      } catch (_) {}
    });
  }

  void _onDone() {
    _connected = false;
    _pingTimer?.cancel();
    debugPrint('ChatService: WS disconnected');
    _scheduleReconnect();
  }

  void _onError(dynamic error) {
    debugPrint('ChatService: WS error: $error');
    _connected = false;
    _pingTimer?.cancel();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () async {
      final token = await _auth.accessToken;
      if (token != null) _openSocket(token);
    });
  }

  // ---------------------------------------------------------------------------
  // Incoming WebSocket events
  // ---------------------------------------------------------------------------

  void _onData(dynamic raw) {
    if (raw is! String) return;
    // Ignore pong responses
    if (raw == 'pong') return;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'new_message':
          final msg = ChatMessage.fromJson(json['message'] as Map<String, dynamic>);
          _messages.add(msg);
          _push();

        case 'edit_message':
          final updated = ChatMessage.fromJson(json['message'] as Map<String, dynamic>);
          final idx = _messages.indexWhere((m) => m.id == updated.id);
          if (idx != -1) {
            _messages[idx] = updated;
            _push();
          }

        case 'delete_message':
          final msgId = json['message_id'] as String;
          final idx = _messages.indexWhere((m) => m.id == msgId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(
              isDeleted: true,
              clearText: true,
              clearImageUrl: true,
            );
            _push();
          }
      }
    } catch (e) {
      debugPrint('ChatService: parse error: $e');
    }
  }

  void _push() => _controller.add(List.unmodifiable(_messages));

  // ---------------------------------------------------------------------------
  // REST: load history
  // ---------------------------------------------------------------------------

  Future<void> _loadHistory({String? beforeId}) async {
    final token = await _auth.accessToken;
    if (token == null) return;

    try {
      final uri = Uri.parse(
        beforeId != null
            ? '$_httpBase/messages?limit=50&before_id=$beforeId'
            : '$_httpBase/messages?limit=50',
      );
      final resp = await http.get(uri, headers: _headers(token));

      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        final loaded = list
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();

        if (beforeId == null) {
          _messages
            ..clear()
            ..addAll(loaded);
        } else {
          _messages.insertAll(0, loaded);
        }
        _push();
      } else if (resp.statusCode == 401) {
        final ok = await _auth.refreshTokens();
        if (ok) await _loadHistory(beforeId: beforeId);
      }
    } catch (e) {
      debugPrint('ChatService: loadHistory error: $e');
    }
  }

  Future<void> loadMore() async {
    if (_messages.isEmpty) return;
    await _loadHistory(beforeId: _messages.first.id);
  }

  // ---------------------------------------------------------------------------
  // REST: send / edit / delete
  // ---------------------------------------------------------------------------

  Future<void> sendTextMessage(String text) async {
    await _post('/messages', {'text': text});
  }

  Future<void> sendImageMessage(String imageUrl) async {
    await _post('/messages', {'image_url': imageUrl});
  }

  Future<void> editMessage(String id, String newText) async {
    final token = await _auth.accessToken;
    if (token == null) return;
    try {
      final resp = await http.put(
        Uri.parse('$_httpBase/messages/$id'),
        headers: _headers(token),
        body: jsonEncode({'text': newText}),
      );
      if (resp.statusCode == 401) {
        final ok = await _auth.refreshTokens();
        if (ok) await editMessage(id, newText);
      }
    } catch (e) {
      debugPrint('ChatService: editMessage error: $e');
    }
  }

  Future<void> deleteMessage(String id) async {
    final token = await _auth.accessToken;
    if (token == null) return;
    try {
      final resp = await http.delete(
        Uri.parse('$_httpBase/messages/$id'),
        headers: _headers(token),
      );
      if (resp.statusCode == 401) {
        final ok = await _auth.refreshTokens();
        if (ok) await deleteMessage(id);
      }
    } catch (e) {
      debugPrint('ChatService: deleteMessage error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Image upload
  // ---------------------------------------------------------------------------

  Future<String?> uploadImage(XFile file) async {
    final token = await _auth.accessToken;
    if (token == null) return null;

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_httpBase/upload-image'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          await http.MultipartFile.fromPath('file', file.path),
        );

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['image_url'] as String?;
      }
    } catch (e) {
      debugPrint('ChatService: uploadImage error: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool isMyMessage(ChatMessage msg) => msg.userId == _currentUserId;

  Future<void> _post(String path, Map<String, dynamic> body) async {
    final token = await _auth.accessToken;
    if (token == null) return;
    try {
      final resp = await http.post(
        Uri.parse('$_httpBase$path'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (resp.statusCode == 401) {
        final ok = await _auth.refreshTokens();
        if (ok) await _post(path, body);
      }
    } catch (e) {
      debugPrint('ChatService: post error: $e');
    }
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
}
