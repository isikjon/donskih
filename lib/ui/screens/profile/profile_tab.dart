import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_avatar.dart';
import '../../components/app_card.dart';
import '../saved/saved_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll({bool silent = false}) async {
    final auth = AuthService();

    // Show cached data instantly
    final cached = await auth.getUser();
    if (cached != null && mounted) {
      setState(() {
        _user = cached;
        _isLoading = false;
      });
    }

    // Always fetch fresh data from network
    if (!silent) setState(() => _isLoading = _user == null);
    final fresh = await auth.fetchProfile();
    if (fresh != null && mounted) {
      setState(() {
        _user = fresh;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
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
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _loadAll(silent: false),
      child: _buildList(),
    );
  }

  Widget _buildList() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
        ),

        // Telegram link card (only if no Telegram linked)
        if (!_isLoading && _user?['telegram_account'] == null) ...[
          const SizedBox(height: 16),
          _buildLinkTelegramCard(),
        ],

        const SizedBox(height: 24),

        // Main menu
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 10,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              ListCard(
                title: 'Сохранённое',
                subtitle: 'Закладки',
                icon: Icons.bookmark_outline,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const SavedScreen()),
                ),
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
                onTap: _openSupport,
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

        // Danger zone: delete account + logout
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 10,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              ListCard(
                title: 'Удалить аккаунт',
                icon: Icons.delete_outline_rounded,
                iconColor: AppColors.error,
                showArrow: false,
                onTap: () => _showDeleteAccount(context),
              ),
              const Divider(height: 1, indent: 56),
              ListCard(
                title: 'Выйти',
                icon: Icons.logout_outlined,
                iconColor: AppColors.error,
                showArrow: false,
                onTap: () => _showLogout(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: 100),
      ],
    );
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
          border: Border.all(
              color: const Color(0xFF0088CC).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.telegram,
                color: Color(0xFF0088CC), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Привязать Telegram',
                      style: AppTypography.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Нажмите Start в боте и поделитесь контактом',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Future<void> _openSupport() async {
    final uri = Uri.parse('https://t.me/DonskihCom');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showClearCache(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Очистить кэш'),
        content: const Text(
            'Будут удалены все загруженные изображения и файлы. Продолжить?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Clear in-memory image cache
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              // Clear CachedNetworkImage disk cache
              await DefaultCacheManager().emptyCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Кэш очищен'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child:
                Text('Очистить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить аккаунт?'),
        content: const Text(
            'Все ваши данные будут удалены безвозвратно. Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: call delete account API endpoint
              await AuthService().logout();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (_) => false);
              }
            },
            child: Text('Удалить',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().logout();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (_) => false);
              }
            },
            child: Text('Выйти',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
