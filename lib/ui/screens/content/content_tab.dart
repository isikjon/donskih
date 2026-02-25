import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/content_item.dart';
import '../../../core/services/content_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../components/app_bookmark.dart';
import '../video/video_player_screen.dart';

class ContentTab extends StatefulWidget {
  const ContentTab({super.key});

  @override
  State<ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<ContentTab> {
  static const ScrollPhysics _refreshPhysics =
      AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());

  final _bookmarks = <String, bool>{};
  Map<String, List<ContentItemDto>>? _contentByDate;
  bool _loading = true;
  final _sectionKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final data = await ContentService().fetchContent();
    if (!mounted) return;
    setState(() {
      _contentByDate = data;
      _loading = false;
    });
  }

  Future<void> _refreshContent() async {
    final data = await ContentService().fetchContent();
    if (!mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось обновить данные')),
      );
      return;
    }
    setState(() {
      _contentByDate = data;
      _loading = false;
    });
  }

  void _openVideo(ContentItemDto item, {String? subTitle}) {
    final url = item.url?.trim();
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Видео еще не загружено')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: url,
          title: subTitle ?? item.title,
        ),
      ),
    );
  }

  Future<void> _openChecklist(ContentItemDto item) async {
    final url = item.url?.trim();
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл чек-листа еще не загружен')),
        );
      }
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Некорректная ссылка на файл')),
        );
      }
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  GlobalKey _keyFor(String id) {
    _sectionKeys[id] ??= GlobalKey();
    return _sectionKeys[id]!;
  }

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
          child: _contentByDate != null && _contentByDate!.isNotEmpty
              ? _ProgramBlockFromApi(
                  contentByDate: _contentByDate!,
                  onItemTap: (id) {
                    final key = _sectionKeys[id];
                    if (key != null) _scrollToSection(key);
                  },
                )
              : _ProgramBlock(onItemTap: (_) {}),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshContent,
            color: AppColors.primary,
            child: _loading
                ? ListView(
                    physics: _refreshPhysics,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      ),
                      SizedBox(height: 400),
                    ],
                  )
                : _contentByDate != null && _contentByDate!.isNotEmpty
                    ? _buildContentFromApi()
                    : _buildMockContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildContentFromApi() {
    final dates = _contentByDate!.keys.toList()..sort((a, b) => b.compareTo(a));
    final list = <Widget>[];
    for (final dateIso in dates) {
      final items = _contentByDate![dateIso]!;
      final dateLabel = ContentItemDto.formatDisplayDate(dateIso);
      list.add(_DateLabel(dateLabel));
      list.add(const SizedBox(height: 8));
      for (final item in items) {
        if (item.isVideo) {
          list.add(
            _ExpandableLessonCard(
              key: _keyFor(item.id),
              id: item.id,
              title: item.title,
              description: item.subtitle ?? '',
              videoUrl: item.url,
              isBookmarked: _isBookmarked(item.id),
              onBookmark: (v) => _toggleBookmark(item.id, v),
              canPlay: (item.url ?? '').trim().isNotEmpty,
              onPlayMain: () => _openVideo(item),
              onPlaySubLesson: (sub) => _openVideo(item, subTitle: sub.title),
              subLessons: item.subItems
                  .map((s) => _SubLessonData(s.title, s.duration ?? '—'))
                  .toList(),
            ),
          );
        } else {
          list.add(
            _ChecklistCard(
              key: _keyFor(item.id),
              title: item.title,
              description: item.subtitle ?? '',
              fileUrl: item.url,
              isBookmarked: _isBookmarked(item.id),
              onBookmark: (v) => _toggleBookmark(item.id, v),
              onTap: () => _openChecklist(item),
            ),
          );
        }
        list.add(const SizedBox(height: 10));
      }
      list.add(const SizedBox(height: 6));
    }
    list.add(const SizedBox(height: 100));
    return ListView(
      physics: _refreshPhysics,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: list,
    );
  }

  Widget _buildMockContent() {
    final keys = {
      'nude_look': GlobalKey(),
      'skin_care': GlobalKey(),
      'brows': GlobalKey(),
      'eyes': GlobalKey(),
      'romantic': GlobalKey(),
      'checklist_bronzer': GlobalKey(),
    };
    for (final e in keys.entries) {
      _sectionKeys[e.key] = e.value;
    }
    return ListView(
      physics: _refreshPhysics,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _DateLabel('06 февраля'),
        const SizedBox(height: 8),
        _ExpandableLessonCard(
          key: keys['nude_look']!,
          id: 'nude_look',
          title: 'Макияж «Нюдовый образ»',
          description: 'Красивый натуральный макияж на каждый день',
          videoUrl: null,
          isBookmarked: _isBookmarked('nude_look'),
          onBookmark: (v) => _toggleBookmark('nude_look', v),
          canPlay: false,
          onPlayMain: () {},
          onPlaySubLesson: (_) {},
          subLessons: const [
            _SubLessonData('Подготовка кожи', '3:42'),
            _SubLessonData('Нанесение тона', '5:18'),
            _SubLessonData('Макияж глаз', '4:55'),
            _SubLessonData('Макияж губ', '2:30'),
          ],
        ),
        const SizedBox(height: 10),
        _ExpandableLessonCard(
          key: keys['skin_care']!,
          id: 'skin_care',
          title: 'Уход за кожей зимой',
          description: 'Увлажнение и защита в холодное время',
          videoUrl: null,
          isBookmarked: _isBookmarked('skin_care'),
          onBookmark: (v) => _toggleBookmark('skin_care', v),
          canPlay: false,
          onPlayMain: () {},
          onPlaySubLesson: (_) {},
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
          key: keys['brows']!,
          id: 'brows',
          title: 'Макияж бровей',
          description: 'Оформление бровей карандашом и гелем',
          videoUrl: null,
          isBookmarked: _isBookmarked('brows'),
          onBookmark: (v) => _toggleBookmark('brows', v),
          canPlay: false,
          onPlayMain: () {},
          onPlaySubLesson: (_) {},
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
          key: keys['eyes']!,
          id: 'eyes',
          title: 'Макияж глаз: стрелки',
          description: 'Идеальные стрелки разными способами',
          videoUrl: null,
          isBookmarked: _isBookmarked('eyes'),
          onBookmark: (v) => _toggleBookmark('eyes', v),
          canPlay: false,
          onPlayMain: () {},
          onPlaySubLesson: (_) {},
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
          key: keys['romantic']!,
          id: 'romantic',
          title: 'Романтичный макияж',
          description: 'Нежный образ для свидания',
          videoUrl: null,
          isBookmarked: _isBookmarked('romantic'),
          onBookmark: (v) => _toggleBookmark('romantic', v),
          canPlay: false,
          onPlayMain: () {},
          onPlaySubLesson: (_) {},
          subLessons: const [
            _SubLessonData('Нежный тон', '4:15'),
            _SubLessonData('Розовые тени', '3:40'),
            _SubLessonData('Nude губы', '2:50'),
          ],
        ),
        const SizedBox(height: 10),
        _ChecklistCard(
          key: keys['checklist_bronzer']!,
          title: 'Чек-лист: Бронзеры и скульпторы',
          description: 'Подборка лучших продуктов для контуринга',
          fileUrl: null,
          isBookmarked: _isBookmarked('checklist_bronzer'),
          onBookmark: (v) => _toggleBookmark('checklist_bronzer', v),
          onTap: () => _showPdfMock(context, 'Бронзеры и скульпторы'),
        ),
        const SizedBox(height: 100),
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
  final String? videoUrl;
  final bool isBookmarked;
  final ValueChanged<bool> onBookmark;
  final bool canPlay;
  final VoidCallback onPlayMain;
  final ValueChanged<_SubLessonData> onPlaySubLesson;
  final List<_SubLessonData> subLessons;

  const _ExpandableLessonCard({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.isBookmarked,
    required this.onBookmark,
    required this.canPlay,
    required this.onPlayMain,
    required this.onPlaySubLesson,
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

  String? _thumbnailUrl(String? videoUrl) {
    if (videoUrl == null || videoUrl.trim().isEmpty) return null;
    final uri = Uri.tryParse(videoUrl.trim());
    if (uri == null) return null;
    if (!uri.path.endsWith('/index.m3u8')) return null;
    final thumbPath =
        uri.path.replaceFirst(RegExp(r'/index\.m3u8$'), '/thumb.jpg');
    return uri.replace(path: thumbPath).toString();
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = _thumbnailUrl(widget.videoUrl);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                InkWell(
                  onTap: widget.canPlay ? widget.onPlayMain : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 72,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (thumbUrl != null)
                            Image.network(
                              thumbUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            ),
                          Container(
                            color: Colors.black.withValues(
                              alpha: thumbUrl == null ? 0.0 : 0.2,
                            ),
                          ),
                          Center(
                            child: Icon(
                              Icons.play_circle_filled_rounded,
                              color: widget.canPlay
                                  ? (thumbUrl == null
                                      ? AppColors.textTertiary
                                      : Colors.white)
                                  : AppColors.textTertiary
                                      .withValues(alpha: 0.45),
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: AppTypography.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(widget.description,
                          style: AppTypography.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                AnimatedBookmark(
                  isBookmarked: widget.isBookmarked,
                  onToggle: widget.onBookmark,
                  size: 20,
                ),
                IconButton(
                  onPressed: _toggle,
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textTertiary,
                    size: 22,
                  ),
                ),
              ],
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
                        child: InkWell(
                          onTap: widget.canPlay
                              ? () => widget.onPlaySubLesson(sub)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: widget.canPlay
                                        ? AppColors.primary
                                        : AppColors.textTertiary
                                            .withValues(alpha: 0.45),
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(sub.title,
                                    style: AppTypography.bodyMedium),
                              ),
                              Text(sub.duration,
                                  style: AppTypography.labelSmall),
                            ],
                          ),
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
  final String? fileUrl;
  final bool isBookmarked;
  final ValueChanged<bool> onBookmark;
  final VoidCallback onTap;

  const _ChecklistCard({
    super.key,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onTap,
  });

  String? _thumbnailUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    if (!uri.path.toLowerCase().endsWith('.pdf')) return null;
    final thumbPath =
        uri.path.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '.jpg');
    return uri.replace(path: thumbPath).toString();
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = _thumbnailUrl(fileUrl);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbUrl != null)
                      Image.network(
                        thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    Container(
                      color: Colors.black.withValues(
                        alpha: thumbUrl == null ? 0.0 : 0.15,
                      ),
                    ),
                    const Center(
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(description,
                      style: AppTypography.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            AnimatedBookmark(
                isBookmarked: isBookmarked, onToggle: onBookmark, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Program block built from API content (dates + first item per date).
class _ProgramBlockFromApi extends StatefulWidget {
  final Map<String, List<ContentItemDto>> contentByDate;
  final ValueChanged<String> onItemTap;

  const _ProgramBlockFromApi({
    required this.contentByDate,
    required this.onItemTap,
  });

  @override
  State<_ProgramBlockFromApi> createState() => _ProgramBlockFromApiState();
}

class _ProgramBlockFromApiState extends State<_ProgramBlockFromApi>
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

  static String _isoToShortDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}.${parts[1]}';
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
    final dates = widget.contentByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
                _isExpanded ? _controller.forward() : _controller.reverse();
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child:
                          Text('Программа', style: AppTypography.titleSmall)),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: dates.map((dateIso) {
                      final items = widget.contentByDate[dateIso]!;
                      final first = items.first;
                      final dateShort = _isoToShortDate(dateIso);
                      return _ProgramItem(
                        date: dateShort,
                        title: first.title,
                        onTap: () => _onItemTap(first.id),
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
          BoxShadow(
              color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
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
                  const Icon(Icons.calendar_month_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child:
                          Text('Программа', style: AppTypography.titleSmall)),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Прошлый месяц',
                          style: AppTypography.labelSmall
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _ProgramItem(
                          date: '16.01',
                          title: 'Макияж «Вечерняя роскошь»',
                          onTap: () {}),
                      _ProgramItem(
                          date: '19.01', title: 'Загар зимой', onTap: () {}),
                      _ProgramItem(
                          date: '23.01',
                          title: 'Накладные ресницы',
                          onTap: () {}),
                      _ProgramItem(
                          date: '26.01', title: 'Яркие губы', onTap: () {}),
                      const Divider(height: 20),
                      Text('Текущий месяц',
                          style: AppTypography.labelSmall
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _ProgramItem(
                          date: '03.02',
                          title: 'Нюдовый образ',
                          onTap: () => _onItemTap('nude_look')),
                      _ProgramItem(
                          date: '06.02',
                          title: 'Уход за кожей',
                          onTap: () => _onItemTap('skin_care')),
                      _ProgramItem(
                          date: '07.02',
                          title: 'Макияж бровей',
                          onTap: () => _onItemTap('brows')),
                      _ProgramItem(
                          date: '10.02',
                          title: 'Стрелки',
                          onTap: () => _onItemTap('eyes')),
                      _ProgramItem(
                          date: '14.02',
                          title: 'Романтичный макияж',
                          onTap: () => _onItemTap('romantic')),
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

  const _ProgramItem(
      {required this.date, required this.title, required this.onTap});

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
              child: Text(date,
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.textTertiary)),
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
                    child: const Icon(Icons.close,
                        size: 18, color: AppColors.textSecondary),
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
                        Icon(Icons.picture_as_pdf_rounded,
                            size: 48,
                            color: AppColors.primary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('Страница ${index + 1}',
                            style: AppTypography.bodyMedium),
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
