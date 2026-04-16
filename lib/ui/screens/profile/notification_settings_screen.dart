import 'package:flutter/material.dart';

import '../../../core/services/notification_prefs_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _prefs = NotificationPrefsService();

  bool _chatEnabled = true;
  bool _lessonEnabled = true;
  bool _adminEnabled = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final chat = await _prefs.chatEnabled;
    final lesson = await _prefs.lessonEnabled;
    final admin = await _prefs.adminEnabled;
    if (mounted) {
      setState(() {
        _chatEnabled = chat;
        _lessonEnabled = lesson;
        _adminEnabled = admin;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('Уведомления', style: AppTypography.headlineSmall),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                Text(
                  'Выберите, какие уведомления вы хотите получать.',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                _card(children: [
                  _toggle(
                    icon: Icons.chat_bubble_outline,
                    title: 'Чат',
                    subtitle: 'Новые сообщения в чате',
                    value: _chatEnabled,
                    onChanged: (v) async {
                      setState(() => _chatEnabled = v);
                      await _prefs.setChatEnabled(v);
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _toggle(
                    icon: Icons.play_lesson_outlined,
                    title: 'Новые уроки',
                    subtitle: 'Уведомления о выходе новых уроков',
                    value: _lessonEnabled,
                    onChanged: (v) async {
                      setState(() => _lessonEnabled = v);
                      await _prefs.setLessonEnabled(v);
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _toggle(
                    icon: Icons.campaign_outlined,
                    title: 'Рассылки',
                    subtitle: 'Объявления и системные уведомления',
                    value: _adminEnabled,
                    onChanged: (v) async {
                      setState(() => _adminEnabled = v);
                      await _prefs.setAdminEnabled(v);
                    },
                  ),
                ]),
              ],
            ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _toggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
