import 'package:shared_preferences/shared_preferences.dart';

class NotificationPrefsService {
  static final NotificationPrefsService _instance =
      NotificationPrefsService._();
  factory NotificationPrefsService() => _instance;
  NotificationPrefsService._();

  static const _keyChatEnabled = 'notif_chat_enabled';
  static const _keyLessonEnabled = 'notif_lesson_enabled';
  static const _keyAdminEnabled = 'notif_admin_enabled';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sp async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<bool> get chatEnabled async =>
      (await _sp).getBool(_keyChatEnabled) ?? true;

  Future<bool> get lessonEnabled async =>
      (await _sp).getBool(_keyLessonEnabled) ?? true;

  Future<bool> get adminEnabled async =>
      (await _sp).getBool(_keyAdminEnabled) ?? true;

  Future<void> setChatEnabled(bool v) async =>
      (await _sp).setBool(_keyChatEnabled, v);

  Future<void> setLessonEnabled(bool v) async =>
      (await _sp).setBool(_keyLessonEnabled, v);

  Future<void> setAdminEnabled(bool v) async =>
      (await _sp).setBool(_keyAdminEnabled, v);

  /// Returns true if notification of [type] should be shown.
  Future<bool> isTypeEnabled(String type) async {
    switch (type) {
      case 'chat':
        return chatEnabled;
      case 'lesson':
        return lessonEnabled;
      case 'admin':
        return adminEnabled;
      default:
        return true;
    }
  }
}
