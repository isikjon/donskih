import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../services/admin_api_service.dart';
import '../services/upload_picker.dart';
import 'admin_content_list_screen.dart';

class AdminContentEditScreen extends StatefulWidget {
  const AdminContentEditScreen({super.key});

  static const routeName = '/admin/content/edit';

  @override
  State<AdminContentEditScreen> createState() => _AdminContentEditScreenState();
}

class _AdminContentEditScreenState extends State<AdminContentEditScreen> {
  final _api = AdminApiService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _urlController = TextEditingController();

  String? _id;
  late String _type;
  DateTime _displayDate = DateTime.now();
  int _sortOrder = 0;
  List<({String title, String duration})> _subItems = [];
  String? _adminKey;
  bool _saving = false;
  bool _uploading = false;
  String? _error;
  bool _initialized = false;
  String? _uploadedFilename;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _id = args['id'] as String?;
      _type = args['type'] as String? ?? 'video';
      if (args['display_date'] != null) {
        final d = DateTime.tryParse(args['display_date'] as String);
        if (d != null) _displayDate = d;
      }
      _titleController.text = args['title'] as String? ?? '';
      _subtitleController.text = args['subtitle'] as String? ?? '';
      _urlController.text = args['url'] as String? ?? '';
      if (_urlController.text.isNotEmpty) {
        _uploadedFilename =
            Uri.tryParse(_urlController.text)?.pathSegments.last;
      }
      _sortOrder = (args['sort_order'] as num?)?.toInt() ?? 0;
      final sub = args['sub_items'] as List<dynamic>?;
      if (sub != null) {
        _subItems = sub.map((e) {
          final m = e as Map<String, dynamic>;
          return (
            title: m['title'] as String? ?? '',
            duration: m['duration'] as String? ?? ''
          );
        }).toList();
      }
    } else {
      _type = 'video';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _displayDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _displayDate = picked);
  }

  void _addSubItem() {
    setState(() => _subItems.add((title: '', duration: '')));
  }

  void _removeSubItem(int i) {
    setState(() => _subItems.removeAt(i));
  }

  Future<void> _uploadVideo() async {
    try {
      _adminKey ??= await _api.getAdminKey();
      if (_adminKey == null || _adminKey!.isEmpty) {
        setState(() => _error = 'Нет ключа администратора');
        return;
      }

      final picked = await pickVideoFile();
      if (picked == null) return;

      setState(() {
        _uploading = true;
        _error = null;
      });
      final uploaded = await _api.uploadVideoBytes(
        _adminKey,
        filename: picked.name,
        bytes: picked.bytes,
      );
      if (!mounted) return;
      setState(() => _uploading = false);

      if (uploaded == null) {
        setState(() => _error = _api.lastError ?? 'Ошибка загрузки файла');
        return;
      }

      setState(() {
        _urlController.text = uploaded['url'] as String? ?? '';
        _uploadedFilename = uploaded['filename'] as String? ?? picked.name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = 'Ошибка выбора файла: $e';
      });
    }
  }

  Future<void> _uploadChecklist() async {
    try {
      _adminKey ??= await _api.getAdminKey();
      if (_adminKey == null || _adminKey!.isEmpty) {
        setState(() => _error = 'Нет ключа администратора');
        return;
      }

      final picked = await pickPdfFile();
      if (picked == null) return;

      setState(() {
        _uploading = true;
        _error = null;
      });
      final uploaded = await _api.uploadChecklistBytes(
        _adminKey,
        filename: picked.name,
        bytes: picked.bytes,
      );
      if (!mounted) return;
      setState(() => _uploading = false);

      if (uploaded == null) {
        setState(() => _error = _api.lastError ?? 'Ошибка загрузки файла');
        return;
      }

      setState(() {
        _urlController.text = uploaded['url'] as String? ?? '';
        _uploadedFilename = uploaded['filename'] as String? ?? picked.name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = 'Ошибка выбора файла: $e';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_type == 'video' && _subItems.any((s) => s.title.trim().isEmpty)) {
      setState(() => _error = 'У всех частей видео должен быть заполнен тайтл');
      return;
    }
    if (_type == 'video' && _urlController.text.trim().isEmpty) {
      setState(() => _error = 'Сначала загрузите видеофайл');
      return;
    }
    if (_type == 'checklist' && _urlController.text.trim().isEmpty) {
      setState(() => _error = 'Сначала загрузите PDF-файл');
      return;
    }

    _adminKey ??= await _api.getAdminKey();
    if (_adminKey == null || _adminKey!.isEmpty) {
      setState(() => _error = 'Нет ключа администратора');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final body = <String, dynamic>{
      'display_date': _displayDate.toIso8601String().split('T').first,
      'title': _titleController.text.trim(),
      'subtitle': _subtitleController.text.trim().isEmpty
          ? null
          : _subtitleController.text.trim(),
      'sort_order': _sortOrder,
    };
    if (_type == 'checklist') {
      body['url'] = _urlController.text.trim().isEmpty
          ? null
          : _urlController.text.trim();
      body['sub_items'] = [];
    } else {
      body['url'] = _urlController.text.trim().isEmpty
          ? null
          : _urlController.text.trim();
      body['sub_items'] = _subItems
          .asMap()
          .entries
          .map((entry) => {
                'title': entry.value.title.trim(),
                'duration': entry.value.duration.trim().isEmpty
                    ? null
                    : entry.value.duration.trim(),
                'sort_order': entry.key,
              })
          .toList();
    }

    bool ok = false;
    if (_id != null) {
      final updated = await _api.updateContent(_adminKey, _id!, body);
      ok = updated != null;
    } else {
      body['type'] = _type;
      final created = await _api.createContent(_adminKey, body);
      ok = created != null;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AdminContentListScreen.routeName,
        (r) => false,
      );
    } else {
      setState(() => _error = _api.lastError ?? 'Ошибка сохранения');
    }
  }

  static String _formatDate(DateTime d) {
    const m = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_id == null ? 'Новый контент' : 'Редактировать'),
        actions: [
          if (_id != null)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Сохранить'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            if (_error != null) ...[
              Text(_error!,
                  style:
                      AppTypography.bodySmall.copyWith(color: AppColors.error)),
              const SizedBox(height: 12),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Дата публикации'),
              subtitle: Text(_formatDate(_displayDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Заголовок'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Обязательно' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subtitleController,
              decoration:
                  const InputDecoration(labelText: 'Подзаголовок (описание)'),
              maxLines: 2,
            ),
            if (_type == 'checklist') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _uploading || _saving ? null : _uploadChecklist,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnPrimary,
                            ),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(_uploading ? 'Загрузка...' : 'Загрузить PDF'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _uploadedFilename ??
                          (_urlController.text.trim().isEmpty
                              ? 'Файл не загружен'
                              : _urlController.text.trim()),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Файл сохраняется на сервере и автоматически подставляется в чек-лист.',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textTertiary),
              ),
            ],
            if (_type == 'video') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _uploading || _saving ? null : _uploadVideo,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnPrimary,
                            ),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(_uploading ? 'Загрузка...' : 'Загрузить видео'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _uploadedFilename ??
                          (_urlController.text.trim().isEmpty
                              ? 'Файл не загружен'
                              : _urlController.text.trim()),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'После загрузки сервер конвертирует файл в HLS (m3u8) и подставит ссылку.',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textTertiary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Части видео (тайтл + длительность)',
                      style: AppTypography.titleSmall),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addSubItem,
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_subItems.length, (i) {
                final idx = i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: _subItems[idx].title,
                          decoration:
                              const InputDecoration(hintText: 'Название части'),
                          onChanged: (v) {
                            setState(() {
                              _subItems[idx] =
                                  (title: v, duration: _subItems[idx].duration);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: _subItems[idx].duration,
                          decoration: const InputDecoration(hintText: '0:00'),
                          onChanged: (v) {
                            setState(() {
                              _subItems[idx] =
                                  (title: _subItems[idx].title, duration: v);
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.error),
                        onPressed: () => _removeSubItem(idx),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.textOnPrimary))
                  : const Text('Сохранить'),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
