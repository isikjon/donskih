import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../services/admin_api_service.dart';

class AdminPushScreen extends StatefulWidget {
  final String? adminKey;
  const AdminPushScreen({super.key, required this.adminKey});

  @override
  State<AdminPushScreen> createState() => _AdminPushScreenState();
}

class _AdminPushScreenState extends State<AdminPushScreen> {
  final _api = AdminApiService();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  bool _sending = false;
  int? _devicesCount;
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingHistory = true);

    final count = await _api.fetchDevicesCount(widget.adminKey);
    final historyData = await _api.fetchPushHistory(widget.adminKey);

    if (!mounted) return;
    setState(() {
      _devicesCount = count;
      if (historyData != null) {
        _history = (historyData['items'] as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }
      _loadingHistory = false;
    });
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = 'Заполните заголовок и текст');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
      _successMessage = null;
    });

    final result = await _api.sendPush(
      widget.adminKey,
      title: title,
      body: body,
    );

    if (!mounted) return;

    if (result != null) {
      final s = result['success'] ?? 0;
      final f = result['failure'] ?? 0;
      setState(() {
        _sending = false;
        _successMessage = 'Отправлено: $s успешно, $f ошибок';
        _titleCtrl.clear();
        _bodyCtrl.clear();
      });
      _loadData();
    } else {
      setState(() {
        _sending = false;
        _error = _api.lastError ?? 'Ошибка отправки';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSendCard(),
        const SizedBox(height: 24),
        _buildHistorySection(),
      ],
    );
  }

  Widget _buildSendCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text('Отправить уведомление', style: AppTypography.headlineSmall),
              const Spacer(),
              if (_devicesCount != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_android_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '$_devicesCount устройств',
                        style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          Text('Заголовок', style: AppTypography.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            decoration: _inputDecoration('Например: Новый урок!'),
            maxLength: 100,
          ),
          const SizedBox(height: 12),

          Text('Текст уведомления', style: AppTypography.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _bodyCtrl,
            decoration: _inputDecoration('Текст, который увидят пользователи...'),
            maxLines: 4,
            maxLength: 500,
          ),
          const SizedBox(height: 16),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: AppTypography.bodySmall.copyWith(color: AppColors.error))),
                  ],
                ),
              ),
            ),

          if (_successMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_successMessage!, style: AppTypography.bodySmall.copyWith(color: AppColors.success))),
                  ],
                ),
              ),
            ),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_sending ? 'Отправка...' : 'Отправить всем', style: AppTypography.button),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text('История отправок', style: AppTypography.titleMedium),
          ],
        ),
        const SizedBox(height: 12),

        if (_loadingHistory)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ))
        else if (_history.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Text('Пока нет отправленных уведомлений', style: AppTypography.bodySmall),
          )
        else
          ...List.generate(_history.length, (i) => _buildHistoryItem(_history[i])),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final sentAt = DateTime.tryParse(item['sent_at'] ?? '') ?? DateTime.now();
    final formatted = DateFormat('dd.MM.yyyy HH:mm', 'ru').format(sentAt.toLocal());
    final success = item['success_count'] ?? 0;
    final failure = item['failure_count'] ?? 0;
    final recipients = item['recipients_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item['title'] ?? '',
                  style: AppTypography.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(formatted, style: AppTypography.labelSmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item['body'] ?? '',
            style: AppTypography.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statChip(Icons.people_outline, '$recipients', AppColors.textSecondary),
              const SizedBox(width: 8),
              _statChip(Icons.check_circle_outline, '$success', AppColors.success),
              const SizedBox(width: 8),
              if (failure > 0)
                _statChip(Icons.error_outline, '$failure', AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(text, style: AppTypography.labelSmall.copyWith(color: color)),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      counterText: '',
    );
  }
}
