import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_avatar.dart';
import '../../components/app_card.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Column(
            children: [
              const AppAvatar(
                name: 'Анна Петрова',
                size: AvatarSize.xlarge,
                imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&q=80',
              ),
              const SizedBox(height: 16),
              Text('Анна Петрова', style: AppTypography.headlineSmall),
              const SizedBox(height: 4),
              Text('anna@gmail.com', style: AppTypography.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SubscriptionStatusCard(),
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
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacementNamed('/auth');
            },
            child: Text('Выйти', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionStatusCard extends StatelessWidget {
  const _SubscriptionStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Доступ активен', style: AppTypography.titleSmall),
                const SizedBox(height: 2),
                Text('до 15 марта 2026', style: AppTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
