import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/content_item.dart';
import '../../../core/services/bookmark_service.dart';
import '../../../core/services/content_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/rich_description_viewer.dart';
import '../../components/app_bookmark.dart';
import '../video/video_player_screen.dart';
// ═══════════════════════════════════════════════════════════════
// MAIN TAB — API-driven (section=base)
// ═══════════════════════════════════════════════════════════════

class BaseTab extends StatefulWidget {
  const BaseTab({super.key});

  @override
  State<BaseTab> createState() => _BaseTabState();
}

class _BaseTabState extends State<BaseTab> {
  static const _physics =
      AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());

  final _bookmarkService = BookmarkService();
  final _bookmarks = <String, bool>{};
  Map<String, List<ContentItemDto>>? _contentByDate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final results = await Future.wait([
      ContentService().fetchContent(section: 'base'),
      _bookmarkService.getAll(),
    ]);
    if (!mounted) return;
    final data = results[0] as Map<String, List<ContentItemDto>>?;
    final saved = results[1] as Set<String>;
    setState(() {
      _contentByDate = data;
      for (final id in saved) {
        _bookmarks[id] = true;
      }
      _loading = false;
    });
  }

  Future<void> _refreshContent() async {
    final data = await ContentService().fetchContent(section: 'base');
    if (!mounted) return;
    setState(() => _contentByDate = data);
  }

  bool _isBookmarked(String id) => _bookmarks[id] == true;

  void _toggleBookmark(String id, bool value) {
    setState(() => _bookmarks[id] = value);
    _bookmarkService.set(id, value: value);
  }

  void _openVideo(ContentItemDto item, {_BaseSubLesson? sub}) {
    final url =
        (sub?.url?.trim().isNotEmpty == true ? sub!.url : item.url)?.trim();
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Видео ещё не загружено')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VideoPlayerScreen(
        videoUrl: url,
        title: sub?.title ?? item.title,
        description: item.subtitle,
      ),
    ));
  }

  Future<void> _openChecklist(ContentItemDto item) async {
    final url = item.url?.trim();
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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
          child: RefreshIndicator(
            onRefresh: _refreshContent,
            color: AppColors.primary,
            child: _loading
                ? ListView(physics: _physics, children: const [
                    SizedBox(height: 120),
                    Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
                    SizedBox(height: 400),
                  ])
                : _contentByDate != null && _contentByDate!.isNotEmpty
                    ? _buildList()
                    : _buildEmpty(),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    final dates = _contentByDate!.keys.toList()..sort((a, b) => a.compareTo(b));
    final widgets = <Widget>[];
    for (final dateIso in dates) {
      final items = _contentByDate![dateIso]!;
      final label = ContentItemDto.formatDisplayDate(dateIso);
      widgets.add(_BaseDateLabel(label));
      widgets.add(const SizedBox(height: 8));
      for (final item in items) {
        final id = item.id.toString();
        if (item.isVideo) {
          widgets.add(_BaseVideoCard(
            item: item,
            isBookmarked: _isBookmarked(id),
            onBookmark: (v) => _toggleBookmark(id, v),
            onPlayMain: () => _openVideo(item),
            onPlaySub: (sub) => _openVideo(item, sub: sub),
          ));
        } else {
          widgets.add(_BaseChecklistCard(
            item: item,
            isBookmarked: _isBookmarked(id),
            onBookmark: (v) => _toggleBookmark(id, v),
            onTap: () => _openChecklist(item),
          ));
        }
        widgets.add(const SizedBox(height: 10));
      }
    }
    widgets.add(const SizedBox(height: 100));
    return ListView(
      physics: _physics,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: widgets,
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: _physics,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.library_books_outlined,
                  size: 56, color: AppColors.border),
              const SizedBox(height: 16),
              Text(
                'База знаний пока пуста',
                style: AppTypography.titleSmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Уроки появятся здесь\nкак только будут добавлены',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-lesson data
// ---------------------------------------------------------------------------

class _BaseSubLesson {
  final String title;
  final String? description;
  final String? url;
  final String duration;
  const _BaseSubLesson(this.title, this.duration,
      {this.description, this.url});
}

// ---------------------------------------------------------------------------
// Date label
// ---------------------------------------------------------------------------

class _BaseDateLabel extends StatelessWidget {
  final String text;
  const _BaseDateLabel(this.text);

  @override
  Widget build(BuildContext context) {
                return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Video card (expandable)
// ---------------------------------------------------------------------------

class _BaseVideoCard extends StatefulWidget {
  final ContentItemDto item;
  final bool isBookmarked;
  final ValueChanged<bool> onBookmark;
  final VoidCallback onPlayMain;
  final ValueChanged<_BaseSubLesson> onPlaySub;

  const _BaseVideoCard({
    required this.item,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onPlayMain,
    required this.onPlaySub,
  });

  @override
  State<_BaseVideoCard> createState() => _BaseVideoCardState();
}

class _BaseVideoCardState extends State<_BaseVideoCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  String? _thumbUrl() {
    final url = widget.item.url?.trim();
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.path.endsWith('/index.m3u8')) return null;
    return uri
        .replace(
            path:
                uri.path.replaceFirst(RegExp(r'/index\.m3u8$'), '/thumb.jpg'))
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = _thumbUrl();
    final canPlay = (widget.item.url ?? '').trim().isNotEmpty;
    final subs = widget.item.subItems
        .map((s) => _BaseSubLesson(s.title, s.duration ?? '',
            description: s.description, url: s.url))
        .toList();

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
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
                children: [
                // Thumbnail / play button
                InkWell(
                  onTap: canPlay ? widget.onPlayMain : null,
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
                      child: Stack(fit: StackFit.expand, children: [
                        if (thumbUrl != null)
                          CachedNetworkImage(
                            imageUrl: thumbUrl,
                          fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const SizedBox(),
                            placeholder: (_, __) =>
                                Container(color: AppColors.surfaceSecondary),
                        ),
                        Container(
                            color: Colors.black.withValues(
                                alpha: thumbUrl == null ? 0 : 0.2)),
                        Center(
                          child: Icon(
                            Icons.play_circle_filled_rounded,
                            color: canPlay
                                ? (thumbUrl == null
                                    ? AppColors.textTertiary
                                    : Colors.white)
                                : AppColors.textTertiary
                                    .withValues(alpha: 0.45),
                            size: 28,
                          ),
                        ),
                      ]),
                    ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(widget.item.title,
                            style: AppTypography.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if ((ContentItemDto.subtitleToPlainText(widget.item.subtitle) ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                        Text(ContentItemDto.subtitleToPlainText(widget.item.subtitle)!,
                            style: AppTypography.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                        ],
                      ),
                    ),
                AnimatedBookmark(
                    isBookmarked: widget.isBookmarked,
                    onToggle: widget.onBookmark,
                    size: 20),
                if (subs.isNotEmpty ||
                    (ContentItemDto.subtitleToPlainText(widget.item.subtitle) ?? '').trim().isNotEmpty)
                  IconButton(
                    onPressed: _toggle,
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textTertiary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          // Expanded: full description + sub-lessons carousel
          SizeTransition(
            sizeFactor: _anim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1),
                if ((ContentItemDto.subtitleToPlainText(widget.item.subtitle) ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: RichDescriptionViewer(
                      subtitle: widget.item.subtitle,
                      textStyle: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (subs.isNotEmpty)
                  _BaseSubLessonCarousel(
                    subLessons: subs,
                    parentVideoUrl: widget.item.url,
                    canPlayParent: canPlay,
                    onPlaySubLesson: widget.onPlaySub,
                  )
                else
                  const SizedBox(height: 12),
              ],
            ),
          ),
      ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-lesson carousel — horizontal PageView with thumbnails + descriptions
// ---------------------------------------------------------------------------

class _BaseSubLessonCarousel extends StatefulWidget {
  final List<_BaseSubLesson> subLessons;
  final String? parentVideoUrl;
  final bool canPlayParent;
  final ValueChanged<_BaseSubLesson> onPlaySubLesson;

  const _BaseSubLessonCarousel({
    required this.subLessons,
    this.parentVideoUrl,
    required this.canPlayParent,
    required this.onPlaySubLesson,
  });

  @override
  State<_BaseSubLessonCarousel> createState() => _BaseSubLessonCarouselState();
}

class _BaseSubLessonCarouselState extends State<_BaseSubLessonCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String? _thumbUrl(String? videoUrl) {
    if (videoUrl == null || videoUrl.trim().isEmpty) return null;
    final uri = Uri.tryParse(videoUrl.trim());
    if (uri == null || !uri.path.endsWith('/index.m3u8')) return null;
    return uri
        .replace(
            path: uri.path
                .replaceFirst(RegExp(r'/index\.m3u8$'), '/thumb.jpg'))
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final hasDescription = widget.subLessons
        .any((s) => s.description != null && s.description!.trim().isNotEmpty);

    return LayoutBuilder(builder: (context, constraints) {
      final thumbWidth = constraints.maxWidth - 24;
      final thumbHeight = thumbWidth * 16 / 9;
      final carouselHeight =
          44 + thumbHeight + (hasDescription ? 130 : 10);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: carouselHeight,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.subLessons.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final sub = widget.subLessons[index];
                final videoUrl = (sub.url?.trim().isNotEmpty == true)
                    ? sub.url
                    : widget.parentVideoUrl;
                final thumbUrl = _thumbUrl(videoUrl);
                final canPlay = (sub.url?.trim().isNotEmpty ?? false) ||
                    widget.canPlayParent;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(sub.title,
                          style: AppTypography.titleSmall
                              .copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: canPlay
                            ? () => widget.onPlaySubLesson(sub)
                            : null,
                        child: AspectRatio(
                          aspectRatio: 9 / 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (thumbUrl != null)
                                    CachedNetworkImage(
                                      imageUrl: thumbUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                          color: AppColors.surfaceSecondary),
                                      errorWidget: (_, __, ___) =>
                                          const SizedBox(),
                                    ),
                                  Container(
                                    color: Colors.black.withValues(
                                        alpha: thumbUrl != null ? 0.15 : 0),
                                  ),
                                  Center(
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.9),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.15),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        color: canPlay
                                            ? AppColors.primary
                                            : AppColors.textTertiary,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                  if (sub.duration.isNotEmpty)
                                    Positioned(
                                      bottom: 10,
                                      right: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          sub.duration,
                                          style: AppTypography.labelSmall
                                              .copyWith(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (sub.description != null &&
                          sub.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            child: RichDescriptionViewer(
                              subtitle: sub.description!,
                              textStyle: AppTypography.bodySmall
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        if (widget.subLessons.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:
                  List.generate(widget.subLessons.length, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isActive ? 20 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color:
                        isActive ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        if (widget.subLessons.length <= 1) const SizedBox(height: 12),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Checklist card
// ---------------------------------------------------------------------------

class _BaseChecklistCard extends StatelessWidget {
  final ContentItemDto item;
  final bool isBookmarked;
  final ValueChanged<bool> onBookmark;
  final VoidCallback onTap;

  const _BaseChecklistCard({
    required this.item,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onTap,
  });

  String? _thumbUrl() {
    final url = item.url?.trim();
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.path.toLowerCase().endsWith('.pdf')) return null;
    return uri
        .replace(
            path: uri.path
                .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '.jpg'))
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = _thumbUrl();
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
                color: AppColors.shadow,
                blurRadius: 10,
                offset: Offset(0, 2)),
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
                child: Stack(fit: StackFit.expand, children: [
                  if (thumbUrl != null)
                    CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox(),
                      placeholder: (_, __) =>
                          Container(color: AppColors.surfaceSecondary),
                    ),
                  Container(
                      color: Colors.black
                          .withValues(alpha: thumbUrl == null ? 0 : 0.15)),
                  const Center(
                    child: Icon(Icons.picture_as_pdf_rounded,
                        color: AppColors.primary, size: 26),
                  ),
                ]),
              ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text(item.title,
                      style: AppTypography.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if ((ContentItemDto.subtitleToPlainText(item.subtitle) ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                    Text(ContentItemDto.subtitleToPlainText(item.subtitle)!,
                        style: AppTypography.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
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

