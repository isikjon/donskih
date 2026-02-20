import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_button.dart';
import '../../components/app_avatar.dart';

/// Детали контента — минималистичный
class ContentDetailScreen extends StatelessWidget {
  const ContentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: const Icon(Icons.arrow_back_outlined, size: 20),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: const Icon(Icons.bookmark_outline, size: 20),
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=800&q=80',
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.surfaceSecondary),
                    errorWidget: (_, __, ___) => Container(color: AppColors.surfaceSecondary),
                  ),
                  Container(color: Colors.black26),
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_outlined, size: 32, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tag & duration
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Видео', style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.schedule_outlined, size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text('15 мин', style: AppTypography.labelSmall),
                      const SizedBox(width: 12),
                      const Icon(Icons.visibility_outlined, size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text('1.2K', style: AppTypography.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text('Как построить личный бренд в косметологии', style: AppTypography.headlineMedium),
                  const SizedBox(height: 24),

                  // Author
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const AppAvatar(
                          name: 'Анна Петрова',
                          imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&q=80',
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Анна Петрова', style: AppTypography.titleSmall),
                              Text('Эксперт', style: AppTypography.bodySmall),
                            ],
                          ),
                        ),
                        TextButton(onPressed: () {}, child: const Text('Подписаться')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Description
                  Text('Описание', style: AppTypography.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                    'В этом видео мы разберём пошаговый алгоритм создания личного бренда для специалистов в сфере красоты.\n\n'
                    '• Как определить свою уникальность\n'
                    '• Как выстроить позиционирование\n'
                    '• Какие каналы использовать\n'
                    '• Как работать с контентом',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.6),
                  ),
                  const SizedBox(height: 32),

                  // Related
                  Text('Похожие материалы', style: AppTypography.titleLarge),
                  const SizedBox(height: 16),
                  _RelatedItem(title: 'Продвижение в Instagram', duration: '12 мин'),
                  _RelatedItem(title: 'Создание контент-плана', duration: '8 мин'),
                  _RelatedItem(title: 'Работа с отзывами', duration: '10 мин'),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: AppButton(
          text: 'Смотреть видео',
          onPressed: () {},
          icon: Icons.play_arrow_outlined,
        ),
      ),
    );
  }
}

class _RelatedItem extends StatelessWidget {
  final String title;
  final String duration;

  const _RelatedItem({required this.title, required this.duration});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.play_circle_outline, color: AppColors.textTertiary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall, maxLines: 2),
                Text(duration, style: AppTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
