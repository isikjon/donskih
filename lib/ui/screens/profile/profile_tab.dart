import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_avatar.dart';
import '../../components/app_card.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _subData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final auth = AuthService();
    var user = await auth.getUser();
    user ??= await auth.fetchProfile();

    var sub = await auth.getSubscription();
    sub ??= await auth.fetchSubscription();

    if (mounted) {
      setState(() {
        _user = user;
        _subData = sub;
        _isLoading = false;
      });
    }
  }

  String _displayName() {
    if (_user == null) return 'Пользователь';
    final tg = _user!['telegram_account'] as Map<String, dynamic>?;
    if (tg != null) {
      final first = tg['first_name'] ?? '';
      final last = tg['last_name'] ?? '';
      final name = '$first $last'.trim();
      if (name.isNotEmpty) return name;
      if (tg['username'] != null) return '@${tg['username']}';
    }
    return _user!['phone'] ?? 'Пользователь';
  }

  String _displaySubtitle() {
    if (_user == null) return '';
    final tg = _user!['telegram_account'] as Map<String, dynamic>?;
    if (tg != null && tg['username'] != null) {
      return '@${tg['username']}';
    }
    return _user!['phone'] ?? '';
  }

  String? _photoUrl() {
    final tg = _user?['telegram_account'] as Map<String, dynamic>?;
    return tg?['photo_url'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 8),
        Center(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : Column(
                  children: [
                    AppAvatar(
                      name: _displayName(),
                      size: AvatarSize.xlarge,
                      imageUrl: _photoUrl(),
                    ),
                    const SizedBox(height: 16),
                    Text(_displayName(), style: AppTypography.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      _displaySubtitle(),
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
        ),
        if (!_isLoading && _user?['telegram_account'] == null) ...[
          const SizedBox(height: 16),
          _buildLinkTelegramCard(),
        ],
        const SizedBox(height: 20),
        _buildSubscriptionCard(),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: const [
              BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              ListCard(
                title: 'Сохранённое',
                subtitle: 'Закладки',
                icon: Icons.bookmark_outline,
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56),
              ListCard(
                title: 'Уведомления',
                icon: Icons.notifications_outlined,
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56),
              ListCard(
                title: 'Поддержка',
                icon: Icons.support_agent_outlined,
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56),
              ListCard(
                title: 'Очистить кэш',
                icon: Icons.cleaning_services_outlined,
                onTap: () => _showClearCache(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: const [
              BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          child: ListCard(
            title: 'Выйти',
            icon: Icons.logout_outlined,
            iconColor: AppColors.error,
            showArrow: false,
            onTap: () => _showLogout(context),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSubscriptionCard() {
    final sub = _subData?['subscription'] as Map<String, dynamic>?;
    final found = _subData?['found'] == true;

    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (!found || sub == null || sub['sub_type'] == null) {
      final telegramLinked = _subData?['telegram_linked'] == true;
      final message = telegramLinked
          ? 'Подписка не оформлена. Оформите подписку в боте.'
          : 'Привяжите Telegram для проверки подписки.';
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.textTertiary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.textTertiary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textTertiary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final isActive = sub['is_active'] == true;
    final subType = sub['sub_type'] as String?;
    final endDateStr = sub['end_date'] as String?;
    final autoRenewal = sub['auto_renewal'] == true;

    String statusText;
    String? dateText;
    Color statusColor;
    IconData statusIcon;

    if (subType == 'infinity') {
      statusText = 'Бессрочная подписка';
      statusColor = AppColors.success;
      statusIcon = Icons.all_inclusive;
    } else if (isActive) {
      statusText = 'Доступ активен';
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle;
      if (endDateStr != null) {
        final endDate = DateTime.tryParse(endDateStr);
        if (endDate != null) {
          dateText = 'до ${_formatDate(endDate)}';
          if (autoRenewal) {
            dateText = '$dateText • автопродление';
          }
        }
      }
    } else {
      statusText = 'Подписка истекла';
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_outlined;
      if (endDateStr != null) {
        final endDate = DateTime.tryParse(endDateStr);
        if (endDate != null) {
          dateText = 'истекла ${_formatDate(endDate)}';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusText, style: AppTypography.titleSmall),
                if (dateText != null) ...[
                  const SizedBox(height: 2),
                  Text(dateText, style: AppTypography.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  Widget _buildLinkTelegramCard() {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('https://t.me/donskih_authorization_bot');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0088CC).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF0088CC).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.telegram, color: Color(0xFF0088CC), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Привязать Telegram', style: AppTypography.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Нажмите Start в боте и поделитесь контактом',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  void _showClearCache(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Очистить кэш'),
        content: const Text('Будут удалены все загруженные данные. Продолжить?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Кэш очищен')),
              );
            },
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }

  void _showLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
              }
            },
            child: Text('Выйти', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
