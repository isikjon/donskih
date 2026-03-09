import 'package:flutter/material.dart';

import '../../core/models/content_item.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../services/admin_api_service.dart';
import 'admin_content_edit_screen.dart';
// ---------------------------------------------------------------------------
// Body widget — используется в AdminMainScreen (таб "Контент")
// ---------------------------------------------------------------------------

class AdminContentListBody extends StatefulWidget {
  final String? adminKey;
  final String section; // 'main' | 'base'
  const AdminContentListBody({super.key, this.adminKey, this.section = 'main'});

  @override
  State<AdminContentListBody> createState() => _AdminContentListBodyState();
}

class _AdminContentListBodyState extends State<AdminContentListBody> {
  final _api = AdminApiService();
  List<Map<String, dynamic>>? _items;
  String? _adminKey;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AdminContentListBody old) {
    super.didUpdateWidget(old);
    if (widget.adminKey != old.adminKey && widget.adminKey != null) {
      _load();
    }
  }

  Future<void> _load() async {
    final key = widget.adminKey ?? await _api.getAdminKey();
    if (!mounted) return;
    setState(() {
      _adminKey = key;
      _loading = true;
      _error = null;
    });
    final list = await _api.fetchContentList(key, section: widget.section);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
      if (list == null) _error = _api.lastError ?? 'Ошибка загрузки';
    });
  }

  void _addContent(String type) {
    Navigator.of(context)
        .pushNamed(AdminContentEditScreen.routeName,
            arguments: {'type': type, 'section': widget.section})
        .then((_) => _load());
  }

  void _editContent(Map<String, dynamic> item) {
    // Ensure section is propagated to edit screen
    final args = Map<String, dynamic>.from(item);
    args['section'] ??= widget.section;
    Navigator.of(context)
        .pushNamed(AdminContentEditScreen.routeName, arguments: args)
        .then((_) => _load());
  }

  Future<void> _deleteContent(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('«${item['title']}» будет удалён.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await _api.deleteContent(_adminKey, item['id'] as String);
    if (ok && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_loading)
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else if (_error != null)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, style: AppTypography.bodyMedium.copyWith(color: AppColors.error)),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Повторить')),
              ],
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _load,
            child: _items == null || _items!.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                    children: [
                      const SizedBox(height: 48),
                      Text(
                        'Нет контента. Нажмите + чтобы добавить.',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                    children: _buildGroupedList(),
                  ),
          ),
        if (!_loading && _error == null)
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.play_circle_outline, color: AppColors.primary),
                        title: const Text('Видео с тайтлами'),
                        onTap: () { Navigator.pop(ctx); _addContent('video'); },
                      ),
                      ListTile(
                        leading: const Icon(Icons.checklist_rounded, color: AppColors.primary),
                        title: const Text('Чек-лист'),
                        onTap: () { Navigator.pop(ctx); _addContent('checklist'); },
                      ),
                    ],
                  ),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
              backgroundColor: AppColors.primary,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildGroupedList() {
    if (_items == null) return [];
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final item in _items!) {
      final d = item['display_date'] as String? ?? '';
      byDate.putIfAbsent(d, () => []).add(item);
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    final list = <Widget>[];
    for (final date in dates) {
      list.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          _formatDate(date),
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
      for (final item in byDate[date]!) {
        final type = item['type'] as String? ?? 'video';
        list.add(Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Icon(
              type == 'video' ? Icons.play_circle_outline : Icons.checklist_rounded,
              color: AppColors.primary,
            ),
            title: Text(
              item['title'] as String? ?? '',
              style: AppTypography.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: item['subtitle'] != null
                ? Text(
                    ContentItemDto.subtitleToPlainText(item['subtitle'] as String) ?? '',
                    style: AppTypography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _editContent(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                  onPressed: () => _deleteContent(item),
                ),
              ],
            ),
            onTap: () => _editContent(item),
          ),
        ));
      }
    }
    list.add(const SizedBox(height: 100));
    return list;
  }

  String _formatDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    final month = (int.tryParse(parts[1]) ?? 1) - 1;
    if (month < 0 || month >= months.length) return iso;
    return '${parts[2]} ${months[month]}';
  }
}

// ---------------------------------------------------------------------------
// Legacy full-screen (сохранён для старых роутов)
// ---------------------------------------------------------------------------

class AdminContentListScreen extends StatelessWidget {
  const AdminContentListScreen({super.key});
  static const routeName = '/admin/content';

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: AdminContentListBody(),
    );
  }
}
