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
                title: 'Видео Урок 1: Макияж Clean Girl с акцентом на сияющую здоровую кожу',
                icon: Icons.play_circle_outline,
                preview: _LessonPreview(index: 1),
                content: Column(
                  children: [
                    _SubLessonCard(
                      title: 'Уход',
                      products: const [
                        _ProductData('CLARINS lotion tonique apaisante', 'https://goldapple.ru/19760334995-lotion-tonique-apaisante'),
                        _ProductData('ART & FACT 3D Hyaluronic Acid', 'https://goldapple.ru/19000039339-3d-hyaluronic-acid-2-provitamin-b5-moisturizing-biorevitalization-effect'),
                        _ProductData('ORIKO Крем для лица', 'https://ozon.ru/t/baTZ97r'),
                        _ProductData('DERMA FACTORY Стик', 'https://www.wildberries.ru/catalog/146474923/detail.aspx?size=246545503'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SubLessonCard(
                      title: 'Нанесение тона и консилера',
                      products: const [
                        _ProductData('CHARLOTTE TILBURY Hollywood Filter', 'https://www.charlottetilbury.com/us/product/hollywood-flawless-filter-shade-4-5-medium'),
                        _ProductData('CATRICE Soft Glam Filter', 'https://goldapple.ru/19000263133-soft-glam-filter-fluid'),
                        _ProductData('BELOR DESIGN Funhouse Skin', 'https://goldapple.ru/19000187196-funhouse-skin-teen'),
                        _ProductData('NATALYA SHIK Concealer', 'https://goldapple.ru/19000334042-concealer-blurring-effect'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SubLessonCard(
                      title: 'Скульптурирование лица',
                      products: const [
                        _ProductData('RARE BEAUTY Румяна Hope', 'https://www.rarebeauty.com/?srsltid=AfmBOooPMJHnLXcBupTDWBxNwFthUHCw7kfjucNyfEqSrhCcYLvYEPE2'),
                        _ProductData('OK BEAUTY Color Salute Safari', 'https://goldapple.ru/15840800001-color-salute'),
                        _ProductData('CHARLOTTE TILBURY Beauty Light Wand', 'https://www.charlottetilbury.com/us/product/hollywood-beauty-light-wand-highlighter'),
                        _ProductData('STELLARY Cashmere Blush', 'https://goldapple.ru/19000374454-cashmere-blush'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SubLessonCard(
                      title: 'Макияж бровей',
                      products: const [
                        _ProductData('VIVIENNE SABO Brow Arcade', 'https://goldapple.ru/3226300001-brow-arcade-slim'),
                        _ProductData('LUXVISAGE Brow Laminator', 'https://goldapple.ru/19000314269-brow-laminator-extreme-fix-24h'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SubLessonCard(
                      title: 'Макияж глаз',
                      products: const [
                        _ProductData('STELLARY Mousse Highlighter', 'https://goldapple.ru/19000374458-mousse-highlighter-rich-glow'),
                        _ProductData('CATRICE Sun Lover Bronzer', 'https://goldapple.ru/69987500001-sun-lover-glow-bronzing-powder'),
                        _ProductData('SHIKSTUDIO Kajal Liner 02', 'https://goldapple.ru/70062600002-kajal-liner'),
                        _ProductData('ROMANOVAMAKEUP Sexy Eyeshadow', 'https://goldapple.ru/19000174507-sexy-eyeshadow-palette'),
                        _ProductData('ESSENCE Lash Brown Mascara', 'https://goldapple.ru/19000282960-lash-without-limits-brown-extreme-lengthening-volume'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SubLessonCard(
                      title: 'Макияж губ',
                      products: const [
                        _ProductData('LOVE GENERATION Lip Pencil 09', 'https://goldapple.ru/19000251663-lip-pencil'),
                        _ProductData('VIVIENNE SABO Le Grand Volume 01', 'https://goldapple.ru/19760304887-le-grand-volume'),
                        _ProductData('SHIKSTUDIO Intense Gloss 04', 'https://goldapple.ru/19000058261-intense'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppExpandableBlock(
                title: 'Видео Урок 2: Какие кисти должны быть в косметичке',
                icon: Icons.play_circle_outline,
                preview: _LessonPreview(index: 2),
                content: Column(
                  children: [
                    _SubLessonCard(
                      title: 'Кисти для тона и кремовых продуктов',
                      products: const [
                        _ProductData('NATALYA SHIK Foundation & Sculptor', 'https://goldapple.ru/19000386766-brush-03-foundation-sculptor'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SubLessonCard(
                      title: 'Кисти для сухих продуктов',
                      products: const [
                        _ProductData('NATALYA SHIK Powder Brush', 'https://goldapple.ru/19000386764-brush-01-powder'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SubLessonCard(
                      title: 'Кисти для теней и растушевки',
                      products: const [
                        _ProductData('NATALYA SHIK Blending Eyeshadow', 'https://goldapple.ru/19000386768-brush-05-blending-eyeshadow'),
                        _ProductData('MANLY PRO К53', 'https://goldapple.ru/19000323328-round-pencil-brush-for-shadows-and-eyeliner'),
                        _ProductData('PIMINOVA VALERY GS3', 'https://goldapple.ru/19000065740-gs3'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SubLessonCard(
                      title: 'Кисть для подчищений и стрел',
                      products: const [
                        _ProductData('VIVIENNE SABO Sexy Look', 'https://goldapple.ru/19760331864-sexy-look'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SubLessonCard(
                      title: 'Спонж и точилки',
                      products: const [
                        _ProductData('Спонж для макияжа', '#'),
                        _ProductData('Точилка для карандашей', '#'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppExpandableBlock(
                title: 'Видео Урок 3: Как ухаживать за кистями',
                icon: Icons.play_circle_outline,
                preview: _LessonPreview(index: 3),
                content: Column(
                  children: [
                    _SubLessonCard(
                      title: 'Памятка по уходу',
                      products: const [
                        _ProductData('Средство для мытья кистей', '#'),
                        _ProductData('Полотенце для сушки', '#'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppExpandableBlock(
                title: 'Видео Урок 4: Создание контуринга',
                icon: Icons.play_circle_outline,
                preview: _LessonPreview(index: 4),
                content: Column(
                  children: [
                    _SubLessonCard(
                      title: 'Техника контуринга',
                      products: const [
                        _ProductData('Кремовые продукты для контуринга', '#'),
                        _ProductData('Сухие продукты для контуринга', '#'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppExpandableBlock(
                title: 'Чек Лист: Базовый набор для макияжа',
                icon: Icons.checklist_outlined,
                preview: _ChecklistPreview(index: 1),
                content: _ChecklistContent(
                  items: const [
                    'Праймер для лица',
                    'Тональный крем или флюид',
                    'Консилер',
                    'Пудра для фиксации',
                    'Румяна (кремовые или сухие)',
                    'Хайлайтер',
                    'Карандаш для бровей',
                    'Гель для бровей',
                    'Тушь для ресниц',
                    'Карандаш для губ',
                    'Помада или блеск'
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppExpandableBlock(
                title: 'Чек Лист: Кисти для макияжа',
                icon: Icons.checklist_outlined,
                preview: _ChecklistPreview(index: 2),
                content: _ChecklistContent(
                  items: const [
                    'Кисть для тона (плоская)',
                    'Кисть для пудры (пушистая)',
                    'Кисть для румян',
                    'Кисть для хайлайтера',
                    'Кисть для теней (плоская)',
                    'Кисть для растушевки теней',
                    'Тонкая кисть для подводки',
                    'Спонж для макияжа',
                    'Точилка для карандашей'
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppExpandableBlock(
                title: 'Чек Лист: Уход за кожей',
                icon: Icons.checklist_outlined,
                preview: _ChecklistPreview(index: 3),
                content: _ChecklistContent(
                  items: const [
                    'Очищающий гель или пенка',
                    'Тоник для лица',
                    'Сыворотка с гиалуроновой кислотой',
                    'Увлажняющий крем',
                    'SPF защита (днём)',
                    'Ночной крем',
                    'Маска для лица (1-2 раза в неделю)'
                  ],
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
          if (product.url == '#') return;
          final uri = Uri.parse(product.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Text(
          product.name,
          style: AppTypography.bodySmall.copyWith(
            color: product.url == '#' ? AppColors.textSecondary : AppColors.primary,
            decoration: product.url == '#' ? null : TextDecoration.underline,
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