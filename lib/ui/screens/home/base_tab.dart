import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../components/app_expandable_block.dart';

class BaseTab extends StatelessWidget {
  const BaseTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text('База Знаний', style: AppTypography.headlineSmall),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              AppExpandableBlock(
                title: 'Видео Урок 1',
                icon: Icons.play_circle_outline,
                preview: _LessonPreview(index: 1),
                content: Column(
                  children: [
                    _SubLessonCard(
                      title: 'Подготовка кожи к макияжу',
                      products: const [
                        _ProductData('Праймер VIVIENNE SABO', 'https://goldapple.ru'),
                        _ProductData('Тональный крем L\'OREAL Paris infallible', 'https://wildberries.ru'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SubLessonCard(
                      title: 'Макияж бровей',
                      products: const [
                        _ProductData('Карандаш VIVIENNE SABO brow arcade slim 01', 'https://goldapple.ru'),
                        _ProductData('Гель CLIMTCOSMETICS brow fix gel', 'https://wildberries.ru'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SubLessonCard(
                      title: 'Макияж глаз',
                      products: const [
                        _ProductData('Тени SISLEY phyto-eye twist 9 pearl', 'https://goldapple.ru'),
                        _ProductData('Палетка DIOR diorshow 5 couleurs', 'https://goldapple.ru'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SubLessonCard(
                      title: 'Макияж губ',
                      products: const [
                        _ProductData('Карандаш VIVIENNE SABO Le Grand Volume', 'https://goldapple.ru'),
                        _ProductData('Помада L\'OREAL Paris color riche', 'https://wildberries.ru'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppExpandableBlock(
                title: 'Видео Урок 2',
                icon: Icons.play_circle_outline,
                preview: _LessonPreview(index: 2),
                content: Column(
                  children: [
                    _SubLessonCard(
                      title: 'Очищение кожи',
                      products: const [
                        _ProductData('Гель CERAVE', 'https://goldapple.ru'),
                        _ProductData('Мицеллярная вода BIODERMA sensibio', 'https://wildberries.ru'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SubLessonCard(
                      title: 'Тонизирование',
                      products: const [_ProductData('Тоник LA ROCHE-POSAY', 'https://goldapple.ru')],
                    ),
                    const SizedBox(height: 12),
                    _SubLessonCard(
                      title: 'Увлажнение',
                      products: const [
                        _ProductData('Крем CERAVE увлажняющий', 'https://goldapple.ru'),
                        _ProductData('Сыворотка THE ORDINARY hyaluronic acid', 'https://wildberries.ru'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppExpandableBlock(
                title: 'Видео Урок 3',
                icon: Icons.play_circle_outline,
                preview: _LessonPreview(index: 3),
                content: Column(
                  children: [
                    _SubLessonCard(
                      title: 'Подготовка волос',
                      products: const [_ProductData('Термозащита MOROCCANOIL', 'https://goldapple.ru')],
                    ),
                    const SizedBox(height: 12),
                    _SubLessonCard(
                      title: 'Укладка феном',
                      products: const [_ProductData('Мусс WELLA professionals', 'https://wildberries.ru')],
                    ),
                    const SizedBox(height: 12),
                    _SubLessonCard(
                      title: 'Фиксация',
                      products: const [_ProductData('Лак L\'OREAL Paris elnett', 'https://wildberries.ru')],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppExpandableBlock(
                title: 'Видео Урок 4',
                icon: Icons.play_circle_outline,
                preview: _LessonPreview(index: 4),
                content: Column(
                  children: [
                    _SubLessonCard(
                      title: 'Подготовка ногтей',
                      products: const [_ProductData('Масло OPI prospa', 'https://goldapple.ru')],
                    ),
                    const SizedBox(height: 12),
                    _SubLessonCard(
                      title: 'Нанесение покрытия',
                      products: const [
                        _ProductData('Лак ESSIE', 'https://goldapple.ru'),
                        _ProductData('Топ ESSIE speed setter', 'https://goldapple.ru'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppExpandableBlock(
                title: 'Чек Лист 1',
                icon: Icons.checklist_outlined,
                preview: _ChecklistPreview(index: 1),
                content: _ChecklistContent(
                  items: const ['Праймер', 'Тональный крем', 'Консилер', 'Пудра', 'Румяна', 'Хайлайтер', 'Тушь', 'Карандаш для бровей'],
                ),
              ),
              const SizedBox(height: 10),
              AppExpandableBlock(
                title: 'Чек Лист 2',
                icon: Icons.checklist_outlined,
                preview: _ChecklistPreview(index: 2),
                content: _ChecklistContent(
                  items: const ['Гель для умывания', 'Тоник', 'Сыворотка', 'Крем для лица', 'SPF защита', 'Маска (1-2 раза/нед)'],
                ),
              ),
              const SizedBox(height: 10),
              AppExpandableBlock(
                title: 'Чек Лист 3',
                icon: Icons.checklist_outlined,
                preview: _ChecklistPreview(index: 3),
                content: _ChecklistContent(
                  items: const ['Фен с ионизацией', 'Утюжок/выпрямитель', 'Плойка', 'Расчёска-брашинг', 'Термозащита', 'Заколки и зажимы'],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }
}

class _LessonPreview extends StatelessWidget {
  final int index;
  const _LessonPreview({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceSecondary,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.play_circle_filled_rounded, color: AppColors.primary.withValues(alpha: 0.6), size: 22),
          Positioned(
            bottom: 2,
            right: 4,
            child: Text('$index', style: AppTypography.labelSmall.copyWith(fontSize: 9, color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }
}

class _ChecklistPreview extends StatelessWidget {
  final int index;
  const _ChecklistPreview({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight,
      child: Center(
        child: Icon(Icons.checklist_rounded, color: AppColors.primary.withValues(alpha: 0.6), size: 22),
      ),
    );
  }
}

class _ProductData {
  final String name;
  final String url;
  const _ProductData(this.name, this.url);
}

class _SubLessonCard extends StatelessWidget {
  final String title;
  final List<_ProductData> products;

  const _SubLessonCard({required this.title, required this.products});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          ),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.titleSmall),
              const SizedBox(height: 6),
              ...products.map((p) => _ProductLink(product: p)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductLink extends StatelessWidget {
  final _ProductData product;
  const _ProductLink({required this.product});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: GestureDetector(
        onTap: () async {
          final uri = Uri.parse(product.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Text(
          product.name,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _ChecklistContent extends StatelessWidget {
  final List<String> items;
  const _ChecklistContent({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(child: Text(item, style: AppTypography.bodyMedium)),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
