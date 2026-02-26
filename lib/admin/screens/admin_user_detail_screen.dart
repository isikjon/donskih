import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../services/admin_api_service.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final String userId;
  final String? adminKey;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
    this.adminKey,
  });

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  final _api = AdminApiService();
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final key = widget.adminKey ?? await _api.getAdminKey();
    final data = await _api.fetchUserDetail(key, widget.userId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _user = data;
      _error = data == null ? (_api.lastError ?? 'Ошибка загрузки') : null;
    });
  }

  Future<void> _toggleBlock() async {
    if (_user == null) return;
    final isActive = _user!['is_active'] as bool? ?? true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isActive ? 'Заблокировать пользователя?' : 'Разблокировать?'),
        content: Text(isActive
            ? 'Пользователь потеряет доступ к приложению.'
            : 'Пользователь снова получит доступ.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: isActive ? AppColors.error : AppColors.success,
            ),
            child: Text(isActive ? 'Заблокировать' : 'Разблокировать'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _actionLoading = true);
    final key = widget.adminKey ?? await _api.getAdminKey();
    final ok = isActive
        ? await _api.blockUser(key, widget.userId)
        : await _api.unblockUser(key, widget.userId);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (ok) _load();
  }

  Future<void> _deleteChatMessage(String messageId) async {
    final key = widget.adminKey ?? await _api.getAdminKey();
    final ok = await _api.adminDeleteChatMessage(key, messageId);
    if (ok && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          _user != null ? (_user!['telegram']?['display_name'] ?? _user!['phone'] ?? 'Пользователь') : 'Пользователь',
          style: AppTypography.titleSmall,
        ),
        actions: [
          if (_user != null && !_loading)
            _actionLoading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  )
                : IconButton(
                    icon: Icon(
                      (_user!['is_active'] as bool? ?? true) ? Icons.block_outlined : Icons.check_circle_outline,
                      color: (_user!['is_active'] as bool? ?? true) ? AppColors.error : AppColors.success,
                    ),
                    tooltip: (_user!['is_active'] as bool? ?? true) ? 'Заблокировать' : 'Разблокировать',
                    onPressed: _toggleBlock,
                  ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: AppTypography.bodyMedium.copyWith(color: AppColors.error)),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Повторить')),
                  ]),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final user = _user!;
    final tg = user['telegram'] as Map<String, dynamic>?;
    final sub = user['subscription'] as Map<String, dynamic>?;
    final payments = (user['payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final messages = (user['recent_messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(user, tg),
          const SizedBox(height: 16),
          _buildSubscriptionCard(sub),
          if (payments.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildPaymentsCard(payments),
          ],
          if (messages.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMessagesCard(messages),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> user, Map<String, dynamic>? tg) {
    final isActive = user['is_active'] as bool? ?? true;
    final name = tg?['display_name'] as String?;
    final username = tg?['username'] as String?;
    final photoUrl = tg?['photo_url'] as String?;
    final phone = user['phone'] as String? ?? '';

    return _SectionCard(
      title: 'Профиль',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(
                child: photoUrl != null
                    ? CachedNetworkImage(imageUrl: photoUrl, width: 56, height: 56, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _avatarPlaceholder(name ?? phone))
                    : _avatarPlaceholder(name ?? phone),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name != null)
                      Text(name, style: AppTypography.titleSmall),
                    if (username != null)
                      Text('@$username',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.primary)),
                    GestureDetector(
                      onTap: () => Clipboard.setData(ClipboardData(text: phone)),
                      child: Text(phone,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'Активен' : 'Заблокирован',
                  style: AppTypography.labelSmall.copyWith(
                    color: isActive ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow('ID', '${(user['id'] as String).substring(0, 8)}...', copyValue: user['id'] as String),
          _InfoRow('Регистрация', _formatDate(user['created_at'] as String?)),
          if (user['last_active_at'] != null)
            _InfoRow('Последняя активность', _formatDate(user['last_active_at'] as String?)),
          if (tg != null)
            _InfoRow('Telegram привязан', _formatDate(tg['linked_at'] as String?)),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic>? sub) {
    if (sub == null) {
      return _SectionCard(
        title: 'Подписка',
        icon: Icons.star_outline_rounded,
        child: Text('Данные не найдены в боте',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
      );
    }

    final isActive = sub['is_active'] as bool? ?? false;
    final subType = sub['sub_type'] as String?;
    final endDate = sub['end_date'] as String?;
    final subDate = sub['sub_date'] as String?;
    final autoRenewal = sub['auto_renewal'] as bool? ?? false;
    final isTest = sub['is_test'] as bool? ?? false;
    final role = sub['role'] as String? ?? 'user';

    return _SectionCard(
      title: 'Подписка',
      icon: Icons.star_outline_rounded,
      headerTrailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isActive ? 'Активна' : 'Неактивна',
          style: AppTypography.labelSmall.copyWith(
            color: isActive ? AppColors.success : AppColors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Column(
        children: [
          if (subType != null) _InfoRow('Тип', _subTypeLabel(subType)),
          if (subDate != null) _InfoRow('Дата подписки', _formatDateTime(subDate)),
          if (endDate != null) _InfoRow('Действует до', _formatDateTime(endDate)),
          _InfoRow('Авто-продление', autoRenewal ? 'Да' : 'Нет'),
          if (isTest) _InfoRow('Тип аккаунта', 'Тестовый'),
          if (role != 'user') _InfoRow('Роль', role),
        ],
      ),
    );
  }

  Widget _buildPaymentsCard(List<Map<String, dynamic>> payments) {
    return _SectionCard(
      title: 'История оплат',
      icon: Icons.payment_outlined,
      child: Column(
        children: payments.map((p) {
          final status = p['status'] as String? ?? '';
          final isSuccess = status == 'success' || status == 'completed';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: (isSuccess ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle_outline : Icons.pending_outlined,
                    size: 18,
                    color: isSuccess ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p['cost'] ?? ''} ₽ — ${_subTypeLabel(p['sub_type'] as String? ?? '')}',
                        style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${p['pay_type'] ?? ''} · ${p['datetime'] ?? ''}',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                Text(
                  status,
                  style: AppTypography.labelSmall.copyWith(
                    color: isSuccess ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessagesCard(List<Map<String, dynamic>> messages) {
    return _SectionCard(
      title: 'Последние сообщения в чате',
      icon: Icons.chat_bubble_outline_rounded,
      child: Column(
        children: messages.map((msg) {
          final isDeleted = msg['is_deleted'] as bool? ?? false;
          final text = msg['text'] as String?;
          final imageUrl = msg['image_url'] as String?;
          final msgId = msg['id'] as String;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDeleted ? AppColors.surfaceSecondary : AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isDeleted)
                          Text('Удалено',
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.textTertiary, fontStyle: FontStyle.italic))
                        else if (imageUrl != null)
                          Row(children: [
                            const Icon(Icons.image_outlined, size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text('Фото', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                          ])
                        else if (text != null)
                          Text(text, style: AppTypography.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(msg['created_at'] as String? ?? ''),
                          style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  if (!isDeleted)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: () => _deleteChatMessage(msgId),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _avatarPlaceholder(String name) {
    final letters = name.trim().split(' ').where((e) => e.isNotEmpty).take(2).map((e) => e[0].toUpperCase()).join();
    return Container(
      width: 56, height: 56,
      color: AppColors.primaryLight,
      child: Center(
        child: Text(letters.isEmpty ? '?' : letters,
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
    );
  }

  String _subTypeLabel(String type) {
    switch (type) {
      case 'infinity': return 'Безлимитная';
      case 'paid': return 'Платная';
      default: return type;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) { return iso; }
  }

  String _formatDateTime(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }
}

// ---------------------------------------------------------------------------
// Shared UI components
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? headerTrailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: AppTypography.labelMedium.copyWith(
                          color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                ),
                if (headerTrailing != null) headerTrailing!,
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final String? copyValue;

  const _InfoRow(this.label, this.value, {this.copyValue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: copyValue != null
                  ? () => Clipboard.setData(ClipboardData(text: copyValue!))
                  : null,
              child: Text(
                value ?? '—',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                  decoration:
                      copyValue != null ? TextDecoration.underline : null,
                  decorationColor: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
