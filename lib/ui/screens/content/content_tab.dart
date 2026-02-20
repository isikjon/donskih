import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../components/app_bookmark.dart';

class ContentTab extends StatefulWidget {
  const ContentTab({super.key});

  @override
  State<ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<ContentTab> {
  final GlobalKey _nudeLookKey = GlobalKey();
  final GlobalKey _skinCareKey = GlobalKey();
  final GlobalKey _browsKey = GlobalKey();
  final GlobalKey _eyesKey = GlobalKey();
  final GlobalKey _romanticKey = GlobalKey();
  final GlobalKey _checklistKey = GlobalKey();
  final _bookmarks = <String, bool>{};

  void _scrollToSection(GlobalKey key) {
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _isBookmarked(String id) => _bookmarks[id] == true;

  void _toggleBookmark(String id, bool value) {
    setState(() => _bookmarks[id] = value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text('Главная', style: AppTypography.headlineSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ProgramBlock(
            onItemTap: (String id) {
              final keys = <String, GlobalKey>{
                'nude_look': _nudeLookKey,
                'skin_care': _skinCareKey,
                'brows': _browsKey,
                'eyes': _eyesKey,
                'romantic': _romanticKey,
                'checklist_bronzer': _checklistKey,
              };
              final key = keys[id];
              if (key != null) _scrollToSection(key);
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _DateLabel('06 февраля'),
              const SizedBox(height: 8),
              _ExpandableLessonCard(
                key: _nudeLookKey,
                id: 'nude_look',
                title: 'Макияж «Нюдовый образ»',
                description: 'Красивый натуральный макияж на каждый день',
                isBookmarked: _isBookmarked('nude_look'),
                onBookmark: (v) => _toggleBookmark('nude_look', v),
                subLessons: const [
                  _SubLessonData('Подготовка кожи', '3:42'),
                  _SubLessonData('Нанесение тона', '5:18'),
                  _SubLessonData('Макияж глаз', '4:55'),
                  _SubLessonData('Макияж губ', '2:30'),
                ],
              ),
              const SizedBox(height: 10),
              _ExpandableLessonCard(
                key: _skinCareKey,
                id: 'skin_care',
                title: 'Уход за кожей зимой',
                description: 'Увлажнение и защита в холодное время',
                isBookmarked: _isBookmarked('skin_care'),
                onBookmark: (v) => _toggleBookmark('skin_care', v),
                subLessons: const [
                  _SubLessonData('Очищение', '4:10'),
                  _SubLessonData('Увлажнение', '3:45'),
                  _SubLessonData('Защита SPF', '2:20'),
                ],
              ),
              const SizedBox(height: 16),
              _DateLabel('07 февраля'),
              const SizedBox(height: 8),
              _ExpandableLessonCard(
                key: _browsKey,
                id: 'brows',
                title: 'Макияж бровей',
                description: 'Оформление бровей карандашом и гелем',
                isBookmarked: _isBookmarked('brows'),
                onBookmark: (v) => _toggleBookmark('brows', v),
                subLessons: const [
                  _SubLessonData('Форма бровей', '3:20'),
                  _SubLessonData('Заполнение', '4:00'),
                  _SubLessonData('Фиксация', '2:10'),
                ],
              ),
              const SizedBox(height: 16),
              _DateLabel('10 февраля'),
              const SizedBox(height: 8),
              _ExpandableLessonCard(
                key: _eyesKey,
                id: 'eyes',
                title: 'Макияж глаз: стрелки',
                description: 'Идеальные стрелки разными способами',
                isBookmarked: _isBookmarked('eyes'),
                onBookmark: (v) => _toggleBookmark('eyes', v),
                subLessons: const [
                  _SubLessonData('Классическая стрелка', '5:00'),
                  _SubLessonData('Smoky стрелка', '4:30'),
                  _SubLessonData('Двойная стрелка', '3:50'),
                ],
              ),
              const SizedBox(height: 16),
              _DateLabel('14 февраля'),
              const SizedBox(height: 8),
              _ExpandableLessonCard(
                key: _romanticKey,
                id: 'romantic',
                title: 'Романтичный макияж',
                description: 'Нежный образ для свидания',
                isBookmarked: _isBookmarked('romantic'),
                onBookmark: (v) => _toggleBookmark('romantic', v),
                subLessons: const [
                  _SubLessonData('Нежный тон', '4:15'),
                  _SubLessonData('Розовые тени', '3:40'),
                  _SubLessonData('Nude губы', '2:50'),
                ],
              ),
              const SizedBox(height: 10),
              _ChecklistCard(
                key: _checklistKey,
                title: 'Чек-лист: Бронзеры и скульпторы',
                description: 'Подборка лучших продуктов для контуринга',
                isBookmarked: _isBookmarked('checklist_bronzer'),
                onBookmark: (v) => _toggleBookmark('checklist_bronzer', v),
                onTap: () => _showPdfMock(context, 'Бронзеры и скульпторы'),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  void _showPdfMock(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PdfMockViewer(title: title),
    );
  }
}

class _DateLabel extends StatelessWidget {
  final String text;
  const _DateLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.labelMedium.copyWith(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SubLessonData {
  final String title;
  final String duration;
  const _SubLessonData(this.title, this.duration);
}

class _ExpandableLessonCard extends StatefulWidget {
  final String id;
  final String title;
  final String description;
  final bool isBookmarked;
  final ValueChanged<bool> onBookmark;
  final List<_SubLessonData> subLessons;

  const _ExpandableLessonCard({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    required this.isBookmarked,
    required this.onBookmark,
    required this.subLessons,
  });

  @override
  State<_ExpandableLessonCard> createState() => _ExpandableLessonCardState();
}

class _ExpandableLessonCardState extends State<_ExpandableLessonCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    _isExpanded ? _controller.forward() : _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.play_circle_filled_rounded, color: AppColors.textTertiary, size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: AppTypography.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(widget.description, style: AppTypography.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  AnimatedBookmark(
                    isBookmarked: widget.isBookmarked,
                    onToggle: widget.onBookmark,
                    size: 20,
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textTertiary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _animation,
            child: Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: widget.subLessons.map((sub) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 22),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(sub.title, style: AppTypography.bodyMedium),
                            ),
                            Text(sub.duration, style: AppTypography.labelSmall),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isBookmarked;
  final ValueChanged<bool> onBookmark;
  final VoidCallback onTap;

  const _ChecklistCard({
    super.key,
    required this.title,
    required this.description,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.description_rounded, color: AppColors.primary, size: 28),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(description, style: AppTypography.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            AnimatedBookmark(isBookmarked: isBookmarked, onToggle: onBookmark, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ProgramBlock extends StatefulWidget {
  final ValueChanged<String> onItemTap;
  const _ProgramBlock({required this.onItemTap});

  @override
  State<_ProgramBlock> createState() => _ProgramBlockState();
}

class _ProgramBlockState extends State<_ProgramBlock>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    _isExpanded ? _controller.forward() : _controller.reverse();
  }

  void _onItemTap(String id) {
    setState(() => _isExpanded = false);
    _controller.reverse();
    Future.delayed(const Duration(milliseconds: 350), () {
      widget.onItemTap(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Программа', style: AppTypography.titleSmall)),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textTertiary, size: 22,
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _animation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Прошлый месяц', style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _ProgramItem(date: '16.01', title: 'Макияж «Вечерняя роскошь»', onTap: () {}),
                      _ProgramItem(date: '19.01', title: 'Загар зимой', onTap: () {}),
                      _ProgramItem(date: '23.01', title: 'Накладные ресницы', onTap: () {}),
                      _ProgramItem(date: '26.01', title: 'Яркие губы', onTap: () {}),
                      const Divider(height: 20),
                      Text('Текущий месяц', style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _ProgramItem(date: '03.02', title: 'Нюдовый образ', onTap: () => _onItemTap('nude_look')),
                      _ProgramItem(date: '06.02', title: 'Уход за кожей', onTap: () => _onItemTap('skin_care')),
                      _ProgramItem(date: '07.02', title: 'Макияж бровей', onTap: () => _onItemTap('brows')),
                      _ProgramItem(date: '10.02', title: 'Стрелки', onTap: () => _onItemTap('eyes')),
                      _ProgramItem(date: '14.02', title: 'Романтичный макияж', onTap: () => _onItemTap('romantic')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramItem extends StatelessWidget {
  final String date;
  final String title;
  final VoidCallback onTap;

  const _ProgramItem({required this.date, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(date, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
            ),
            Expanded(
              child: Text(
                title,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfMockViewer extends StatelessWidget {
  final String title;
  const _PdfMockViewer({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: AppTypography.titleMedium),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: PageView.builder(
              itemCount: 3,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, size: 48, color: AppColors.primary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('Страница ${index + 1}', style: AppTypography.bodyMedium),
                        const SizedBox(height: 4),
                        Text('PDF Preview', style: AppTypography.labelSmall),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
