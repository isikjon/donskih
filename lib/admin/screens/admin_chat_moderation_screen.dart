import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../services/admin_api_service.dart';

class AdminChatModerationScreen extends StatefulWidget {
  final String? adminKey;
  const AdminChatModerationScreen({super.key, this.adminKey});

  @override
  State<AdminChatModerationScreen> createState() =>
      _AdminChatModerationScreenState();
}

class _AdminChatModerationScreenState
    extends State<AdminChatModerationScreen> {
  final _api = AdminApiService();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;
  bool _hasMore = true;
  Timer? _autoRefresh;

  static const _limit = 50;

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-refresh every 15 seconds
    _autoRefresh = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final key = widget.adminKey ?? await _api.getAdminKey();
    final data = await _api.fetchChatMessages(key, limit: _limit);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = data == null ? (_api.lastError ?? 'Ошибка') : null;
      if (data != null) {
        _messages = data;
        _hasMore = data.length >= _limit;
      }
    });
  }

  Future<void> _refresh() async {
    final key = widget.adminKey ?? await _api.getAdminKey();
    final data = await _api.fetchChatMessages(key, limit: _limit);
    if (!mounted || data == null) return;
    setState(() {
      _messages = data;
      _hasMore = data.length >= _limit;
    });
  }

  Future<void> _loadMore() async {
    if (_messages.isEmpty) return;
    final key = widget.adminKey ?? await _api.getAdminKey();
    final data = await _api.fetchChatMessages(
      key,
      limit: _limit,
      beforeId: _messages.first['id'] as String,
    );
    if (!mounted || data == null) return;
    setState(() {
      _messages = [...data, ..._messages];
      _hasMore = data.length >= _limit;
    });
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Удалить сообщение?', style: AppTypography.titleSmall),
        content: Text('Сообщение будет скрыто для всех пользователей.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final key = widget.adminKey ?? await _api.getAdminKey();
    final ok = await _api.adminDeleteChatMessage(key, messageId);
    if (ok && mounted) {
      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == messageId);
        if (idx != -1) {
          _messages[idx] = {
            ..._messages[idx],
            'is_deleted': true,
            'text': null,
            'image_url': null,
          };
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _error != null
                  ? _buildError()
                  : _buildList(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final activeCount = _messages.where((m) => !(m['is_deleted'] as bool? ?? false)).length;
    final deletedCount = _messages.where((m) => m['is_deleted'] as bool? ?? false).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surface,
      child: Row(
        children: [
          _StatChip(label: 'Всего', value: _messages.length.toString(), color: AppColors.textSecondary),
          const SizedBox(width: 8),
          _StatChip(label: 'Активных', value: activeCount.toString(), color: AppColors.success),
          const SizedBox(width: 8),
          _StatChip(label: 'Удалённых', value: deletedCount.toString(), color: AppColors.error),
          const Spacer(),
          Text('обновляется авто',
              style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: _refresh,
            tooltip: 'Обновить',
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: AppTypography.bodyMedium.copyWith(color: AppColors.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );

  Widget _buildList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            Text('Сообщений нет',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        reverse: true,
        itemCount: _messages.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          if (i >= _messages.length) {
            return TextButton.icon(
              onPressed: _loadMore,
              icon: const Icon(Icons.expand_less),
              label: const Text('Загрузить предыдущие'),
            );
          }
          final msg = _messages[_messages.length - 1 - i];
          return _MessageRow(
            message: msg,
            onDelete: () => _deleteMessage(msg['id'] as String),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _MessageRow extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onDelete;

  const _MessageRow({required this.message, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDeleted = message['is_deleted'] as bool? ?? false;
    final text = message['text'] as String?;
    final imageUrl = message['image_url'] as String?;
    final senderName = message['sender_name'] as String? ?? 'Участник';
    final photoUrl = message['sender_photo_url'] as String?;
    final isEdited = message['is_edited'] as bool? ?? false;
    final timeStr = _formatTime(message['created_at'] as String?);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDeleted ? AppColors.surfaceSecondary : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDeleted ? AppColors.border : AppColors.borderLight,
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(name: senderName, photoUrl: photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(senderName,
                        style: AppTypography.bodySmall
                            .copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const SizedBox(width: 6),
                    Text(timeStr,
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                    if (isEdited) ...[
                      const SizedBox(width: 4),
                      Text('(ред.)',
                          style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textTertiary, fontStyle: FontStyle.italic)),
                    ],
                    const Spacer(),
                    if (isDeleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Удалено',
                            style: AppTypography.labelSmall
                                .copyWith(color: AppColors.error, fontSize: 10)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (isDeleted)
                  Text('Сообщение удалено',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textTertiary, fontStyle: FontStyle.italic))
                else if (imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 200,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 200, height: 120,
                        color: AppColors.surfaceTertiary,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ),
                  ),
                  if (text != null) ...[
                    const SizedBox(height: 4),
                    Text(text, style: AppTypography.bodySmall),
                  ],
                ] else if (text != null)
                  Text(text, style: AppTypography.bodySmall),
              ],
            ),
          ),
          if (!isDeleted) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Удалить',
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  const _Avatar({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: photoUrl != null
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              width: 36, height: 36, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    final letters = name.trim().split(' ').where((e) => e.isNotEmpty).take(2).map((e) => e[0].toUpperCase()).join();
    return Container(
      width: 36, height: 36,
      color: AppColors.primaryLight,
      child: Center(
        child: Text(letters.isEmpty ? '?' : letters,
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: AppTypography.labelSmall
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}
