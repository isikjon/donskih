import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/content_item.dart';

const apiBase = 'https://donskih-cdn.ru/api/v1';

class ContentService {
  static final ContentService _instance = ContentService._();
  factory ContentService() => _instance;
  ContentService._();

  /// GET /api/v1/content → Map<dateISO, List<ContentItemDto>>
  Future<Map<String, List<ContentItemDto>>?> fetchContent() async {
    try {
      final resp = await http.get(
        Uri.parse('$apiBase/content'),
        headers: {'Accept': 'application/json'},
      );
      if (resp.statusCode != 200) return null;
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = <String, List<ContentItemDto>>{};
      for (final e in map.entries) {
        final list = (e.value as List<dynamic>)
            .map((x) => ContentItemDto.fromJson(x as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        result[e.key] = list;
      }
      return result;
    } catch (_) {
      return null;
    }
  }
}
