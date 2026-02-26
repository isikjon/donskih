import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists bookmarked content item IDs to SharedPreferences.
/// Singleton — use BookmarkService() everywhere.
class BookmarkService {
  static final BookmarkService _instance = BookmarkService._();
  factory BookmarkService() => _instance;
  BookmarkService._();

  static const _key = 'bookmarked_ids';

  SharedPreferences? _prefs;
  Set<String> _ids = {};
  bool _loaded = false;

  Future<SharedPreferences> get _sp async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final sp = await _sp;
    final raw = sp.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _ids = list.cast<String>().toSet();
      } catch (_) {
        _ids = {};
      }
    }
    _loaded = true;
  }

  Future<bool> isBookmarked(String id) async {
    await _ensureLoaded();
    return _ids.contains(id);
  }

  /// Returns a snapshot copy of all bookmarked IDs.
  Future<Set<String>> getAll() async {
    await _ensureLoaded();
    return Set.unmodifiable(_ids);
  }

  Future<void> toggle(String id) async {
    await _ensureLoaded();
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
    await _persist();
  }

  Future<void> set(String id, {required bool value}) async {
    await _ensureLoaded();
    if (value) {
      _ids.add(id);
    } else {
      _ids.remove(id);
    }
    await _persist();
  }

  Future<void> _persist() async {
    final sp = await _sp;
    await sp.setString(_key, jsonEncode(_ids.toList()));
  }
}
