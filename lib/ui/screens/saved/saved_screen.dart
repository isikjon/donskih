import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/content_item.dart';
import '../../../core/services/bookmark_service.dart';
import '../../../core/services/content_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../components/app_bookmark.dart';
import '../video/video_player_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final _bookmarkService = BookmarkService();

  List<ContentItemDto> _items = [];
  Set<String> _savedIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      ContentService().fetchContent(),
      _bookmarkService.getAll(),
    ]);

    if (!mounted) return;

    final contentByDate = results[0] as Map<String, List<ContentItemDto>>?;
    final savedIds = results[1] as Set<String>;

    final all = <ContentItemDto>[];
    if (contentByDate != null) {
      for (final items in contentByDate.values) {
        all.addAll(items);
      }
    }

    setState(() {
      _savedIds = savedIds.toSet();
      _items = all.where((i) => _savedIds.contains(i.id.toString())).toList()
        ..sort((a, b) => a.displayDate.compareTo(b.displayDate));
      _loading = false;
    });
  }

  void _toggleBookmark(String id, bool value) {
    setState(() {
      if (value) {
        _savedIds.add(id);
      } else {
        _savedIds.remove(id);
        _items.removeWhere((i) => i.id.toString() == id);
      }
    });
    _bookmarkService.set(id, value: value);
  }

  void _openVideo(ContentItemDto item) {
    final url = item.url?.trim();
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VideoPlayerScreen(
        videoUrl: url,
        title: item.title,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('Сохранённое', style: AppTypography.titleMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _items.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    final id = item.id.toString();
                    final isBookmarked = _savedIds.contains(id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SavedCard(
                        item: item,
                        isBookmarked: isBookmarked,
                        onBookmark: (v) => _toggleBookmark(id, v),
                        onTap: () => item.isVideo
                            ? _openVideo(item)
                            : _openChecklist(item),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bookmark_border_rounded,
              size: 64, color: AppColors.border),
          const SizedBox(height: 16),
          Text('Нет сохранённых материалов',
              style: AppTypography.titleSmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Нажмите на закладку у урока,\nчтобы добавить его сюда',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  final ContentItemDto item;
  final bool isBookmarked;
  final ValueChanged<bool> onBookmark;
  final VoidCallback onTap;

  const _SavedCard({
    required this.item,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onTap,
  });

  String? _thumbnailUrl() {
    final url = item.url?.trim();
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.path.endsWith('/index.m3u8')) {
      return uri
          .replace(path: uri.path.replaceFirst(RegExp(r'/index\.m3u8$'), '/thumb.jpg'))
          .toString();
    }
    if (uri.path.toLowerCase().endsWith('.pdf')) {
      return uri
          .replace(path: uri.path.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '.jpg'))
          .toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = _thumbnailUrl();
    final dateLabel = ContentItemDto.formatDisplayDate(item.displayDate);

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
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 72,
                height: 54,
                color: AppColors.surfaceSecondary,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
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
                          .withValues(alpha: thumbUrl == null ? 0 : 0.15),
                    ),
                    Center(
                      child: Icon(
                        item.isVideo
                            ? Icons.play_circle_filled_rounded
                            : Icons.picture_as_pdf_rounded,
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
                  Text(item.title,
                      style: AppTypography.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.textTertiary),
                  ),
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
