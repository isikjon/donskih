import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../services/admin_api_service.dart';
import '../services/upload_picker.dart';
import 'admin_content_list_screen.dart';

// ---------------------------------------------------------------------------
// Mutable form data for a single video sub-item block
// ---------------------------------------------------------------------------

class _SubItemFormData {
  final TextEditingController titleController;
  QuillController? quillController;
  final FocusNode quillFocusNode;
  String videoUrl;
  String? thumbnailUrl;
  String? uploadedFilename;
  String videoUploadStatus; // idle | uploading | converting | success | error
  double videoUploadProgress;
  double videoConversionProgress;
  String? videoUploadError;
  bool isUploading;
  bool isConverting;
  String? conversionTaskId;

  // Image (photo) upload fields
  String imageUrl;
  String? imageUploadedFilename;
  String imageUploadStatus; // idle | uploading | success | error
  double imageUploadProgress;
  String? imageUploadError;
  bool isImageUploading;

  _SubItemFormData({
    String? title,
    String? description,
    String? url,
    String? imageUrlInit,
  })  : titleController = TextEditingController(text: title ?? ''),
        quillFocusNode = FocusNode(),
        videoUrl = url ?? '',
        thumbnailUrl = null,
        videoUploadStatus =
            url != null && url.isNotEmpty ? 'success' : 'idle',
        videoUploadProgress = 0.0,
        videoConversionProgress = 0.0,
        videoUploadError = null,
        isUploading = false,
        isConverting = false,
        conversionTaskId = null,
        imageUrl = imageUrlInit ?? '',
        imageUploadedFilename = null,
        imageUploadStatus =
            imageUrlInit != null && imageUrlInit.isNotEmpty ? 'success' : 'idle',
        imageUploadProgress = 0.0,
        imageUploadError = null,
        isImageUploading = false {
    if (url != null && url.isNotEmpty) {
      final segs = Uri.tryParse(url)?.pathSegments;
      uploadedFilename = (segs != null && segs.isNotEmpty) ? segs.last : null;
      if (url.endsWith('/index.m3u8')) {
        thumbnailUrl =
            url.replaceFirst(RegExp(r'/index\.m3u8$'), '/thumb.jpg');
      }
    }
    if (imageUrlInit != null && imageUrlInit.isNotEmpty) {
      final segs = Uri.tryParse(imageUrlInit)?.pathSegments;
      imageUploadedFilename =
          (segs != null && segs.isNotEmpty) ? segs.last : null;
    }
    _initQuill(description);
  }

  void _initQuill(String? text) {
    Document doc;
    if (text != null && text.trim().isNotEmpty) {
      final t = text.trim();
      if (t.startsWith('[')) {
        try {
          doc = Document.fromJson(jsonDecode(text) as List<dynamic>);
        } catch (_) {
          doc = Document.fromJson(<Map<String, dynamic>>[
            {'insert': '$t\n'}
          ]);
        }
      } else {
        doc = Document.fromJson(<Map<String, dynamic>>[
          {'insert': '$text\n'}
        ]);
      }
    } else {
      doc = Document();
    }
    quillController = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  bool get isFilled => titleController.text.trim().isNotEmpty;

  String? get descriptionJson {
    if (quillController == null) return null;
    if (quillController!.document.toPlainText().trim().isEmpty) return null;
    return jsonEncode(quillController!.document.toDelta().toJson());
  }

  void dispose() {
    titleController.dispose();
    quillController?.dispose();
    quillFocusNode.dispose();
  }
}

// ---------------------------------------------------------------------------
// Admin Content Edit Screen
// ---------------------------------------------------------------------------

class AdminContentEditScreen extends StatefulWidget {
  const AdminContentEditScreen({super.key});

  static const routeName = '/admin/content/edit';

  @override
  State<AdminContentEditScreen> createState() =>
      _AdminContentEditScreenState();
}

class _AdminContentEditScreenState extends State<AdminContentEditScreen> {
  final _api = AdminApiService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  QuillController? _quillController;
  final _quillFocusNode = FocusNode();

  String? _id;
  late String _type;
  String _section = 'main';
  DateTime _displayDate = DateTime.now();
  int _sortOrder = 0;
  String? _adminKey;
  bool _saving = false;
  String? _error;
  bool _initialized = false;

  // Checklist-specific
  final _checklistUrlController = TextEditingController();
  String? _checklistUploadedFilename;
  bool _checklistUploading = false;

  // Video sub-item blocks
  final List<_SubItemFormData> _subItemForms = [];

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
      _section = args['section'] as String? ?? 'main';
      if (args['display_date'] != null) {
        final d = DateTime.tryParse(args['display_date'] as String);
        if (d != null) _displayDate = d;
      }
      _titleController.text = args['title'] as String? ?? '';
      _initQuillFromSubtitle(args['subtitle'] as String?);
      _sortOrder = (args['sort_order'] as num?)?.toInt() ?? 0;

      if (_type == 'checklist') {
        _checklistUrlController.text = args['url'] as String? ?? '';
        if (_checklistUrlController.text.isNotEmpty) {
          _checklistUploadedFilename =
              Uri.tryParse(_checklistUrlController.text)?.pathSegments.last;
        }
      }

      // Load existing sub-items
      final sub = args['sub_items'] as List<dynamic>?;
      if (sub != null && _type == 'video') {
        for (final e in sub) {
          final m = e as Map<String, dynamic>;
          _subItemForms.add(_SubItemFormData(
            title: m['title'] as String?,
            description: m['description'] as String?,
            url: m['url'] as String?,
            imageUrlInit: m['thumbnail_url'] as String?,
          ));
        }
      }

      // Auto-migrate: old single-video items → one sub-item
      if (_type == 'video' && _subItemForms.isEmpty) {
        final mainUrl = args['url'] as String?;
        if (mainUrl != null && mainUrl.trim().isNotEmpty) {
          _subItemForms.add(_SubItemFormData(url: mainUrl.trim()));
        }
      }
    } else {
      _type = 'video';
      _initQuillFromSubtitle(null);
    }

    // Ensure at least 3 blocks for video, plus 1 extra if all are filled
    if (_type == 'video') {
      while (_subItemForms.length < 3) {
        _subItemForms.add(_SubItemFormData());
      }
      if (_subItemForms.every((f) => f.isFilled)) {
        _subItemForms.add(_SubItemFormData());
      }
      for (final form in _subItemForms) {
        form.titleController.addListener(_onSubItemTitleChanged);
      }
    }
  }

  void _onSubItemTitleChanged() {
    if (_subItemForms.every((f) => f.isFilled)) {
      final newForm = _SubItemFormData();
      newForm.titleController.addListener(_onSubItemTitleChanged);
      setState(() => _subItemForms.add(newForm));
    }
  }

  void _initQuillFromSubtitle(String? subtitle) {
    if (_quillController != null) return;
    Document doc;
    if (subtitle != null && subtitle.trim().isNotEmpty) {
      final t = subtitle.trim();
      if (t.startsWith('[')) {
        try {
          doc = Document.fromJson(jsonDecode(subtitle) as List<dynamic>);
        } catch (_) {
          doc =
              Document.fromJson(<Map<String, dynamic>>[{'insert': '$t\n'}]);
        }
      } else {
        doc = Document.fromJson(
            <Map<String, dynamic>>[{'insert': '$subtitle\n'}]);
      }
    } else {
      doc = Document();
    }
    _quillController = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController?.dispose();
    _quillFocusNode.dispose();
    _checklistUrlController.dispose();
    for (final f in _subItemForms) {
      f.titleController.removeListener(_onSubItemTitleChanged);
      f.dispose();
    }
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

  // -----------------------------------------------------------------------
  // Video upload per sub-item
  // -----------------------------------------------------------------------

  Future<void> _uploadSubItemVideo(int index) async {
    final form = _subItemForms[index];
    try {
      _adminKey ??= await _api.getAdminKey();
      if (_adminKey == null || _adminKey!.isEmpty) {
        setState(() => _error = 'Нет ключа администратора');
        return;
      }

      final nativeFile = await pickVideoNative();
      if (nativeFile == null) return;

      setState(() {
        form.isUploading = true;
        form.isConverting = false;
        form.videoUploadStatus = 'uploading';
        form.videoUploadProgress = 0.0;
        form.videoConversionProgress = 0.0;
        form.videoUploadError = null;
        form.conversionTaskId = null;
        _error = null;
      });

      final uploaded = await _api.uploadVideoNative(
        _adminKey,
        nativeFile: nativeFile,
        onUploadProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() {
            form.videoUploadProgress = (sent / total).clamp(0.0, 1.0);
          });
        },
      );

      if (!mounted) return;

      if (uploaded == null) {
        setState(() {
          form.isUploading = false;
          form.isConverting = false;
          form.videoUploadStatus = 'error';
          form.videoUploadError = _api.lastError ??
              'Ошибка загрузки. Перезагрузите страницу и попробуйте снова.';
        });
        return;
      }

      // Check if backend returned a task_id (two-phase conversion)
      final taskId = uploaded['task_id'] as String?;
      if (taskId != null) {
        setState(() {
          form.isUploading = false;
          form.isConverting = true;
          form.videoUploadStatus = 'converting';
          form.videoUploadProgress = 1.0;
          form.videoConversionProgress = 0.0;
          form.conversionTaskId = taskId;
        });
        await _pollConversionProgress(index, taskId);
      } else {
        // Direct result (e.g. .m3u8 files)
        setState(() {
          form.isUploading = false;
          form.isConverting = false;
          form.videoUrl = uploaded['url'] as String? ?? '';
          form.uploadedFilename = uploaded['filename'] as String?;
          form.thumbnailUrl = uploaded['thumbnail_url'] as String?;
          form.videoUploadStatus = 'success';
          form.videoUploadProgress = 1.0;
          form.videoUploadError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        form.isUploading = false;
        form.isConverting = false;
        form.videoUploadStatus = 'error';
        form.videoUploadError = 'Ошибка выбора файла: $e';
      });
    }
  }

  Future<void> _pollConversionProgress(int index, String taskId) async {
    final form = _subItemForms[index];
    while (mounted && form.conversionTaskId == taskId) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || form.conversionTaskId != taskId) break;

      final progress =
          await _api.getVideoConversionProgress(_adminKey, taskId);
      if (!mounted || form.conversionTaskId != taskId) break;

      if (progress == null) {
        setState(() {
          form.isConverting = false;
          form.videoUploadStatus = 'error';
          form.videoUploadError = _api.lastError ?? 'Потеряна связь с сервером';
        });
        return;
      }

      final status = progress['status'] as String?;
      final prog = (progress['progress'] as num?)?.toDouble() ?? 0.0;

      if (status == 'done') {
        final result = progress['result'] as Map<String, dynamic>?;
        setState(() {
          form.isConverting = false;
          form.videoConversionProgress = 1.0;
          form.videoUrl = result?['url'] as String? ?? '';
          form.uploadedFilename = result?['filename'] as String?;
          form.thumbnailUrl = result?['thumbnail_url'] as String?;
          form.videoUploadStatus = 'success';
          form.videoUploadError = null;
          form.conversionTaskId = null;
        });
        return;
      } else if (status == 'error') {
        setState(() {
          form.isConverting = false;
          form.videoUploadStatus = 'error';
          form.videoUploadError =
              progress['error'] as String? ?? 'Ошибка конвертации';
          form.conversionTaskId = null;
        });
        return;
      } else {
        setState(() {
          form.videoConversionProgress = prog.clamp(0.0, 1.0);
        });
      }
    }
  }

  void _retrySubItemVideoUpload(int index) {
    final form = _subItemForms[index];
    setState(() {
      form.videoUploadStatus = 'idle';
      form.videoUploadError = null;
      form.videoUploadProgress = 0.0;
      form.videoConversionProgress = 0.0;
      form.isConverting = false;
      form.conversionTaskId = null;
    });
    _uploadSubItemVideo(index);
  }

  // -----------------------------------------------------------------------
  // Image upload per sub-item
  // -----------------------------------------------------------------------

  Future<void> _uploadSubItemImage(int index) async {
    final form = _subItemForms[index];
    try {
      _adminKey ??= await _api.getAdminKey();
      if (_adminKey == null || _adminKey!.isEmpty) {
        setState(() => _error = 'Нет ключа администратора');
        return;
      }

      final picked = await pickImageFile();
      if (picked == null) return;

      setState(() {
        form.isImageUploading = true;
        form.imageUploadStatus = 'uploading';
        form.imageUploadProgress = 0.0;
        form.imageUploadError = null;
        _error = null;
      });

      final uploaded = await _api.uploadImageBytes(
        _adminKey,
        filename: picked.name,
        bytes: picked.bytes,
        onUploadProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() {
            form.imageUploadProgress = (sent / total).clamp(0.0, 1.0);
          });
        },
      );

      if (!mounted) return;

      if (uploaded == null) {
        setState(() {
          form.isImageUploading = false;
          form.imageUploadStatus = 'error';
          form.imageUploadError = _api.lastError ?? 'Ошибка загрузки фото';
        });
        return;
      }

      setState(() {
        form.isImageUploading = false;
        form.imageUrl = uploaded['url'] as String? ?? '';
        form.imageUploadedFilename = uploaded['filename'] as String?;
        form.imageUploadStatus = 'success';
        form.imageUploadProgress = 1.0;
        form.imageUploadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        form.isImageUploading = false;
        form.imageUploadStatus = 'error';
        form.imageUploadError = 'Ошибка выбора файла: $e';
      });
    }
  }

  void _retrySubItemImageUpload(int index) {
    final form = _subItemForms[index];
    setState(() {
      form.imageUploadStatus = 'idle';
      form.imageUploadError = null;
      form.imageUploadProgress = 0.0;
    });
    _uploadSubItemImage(index);
  }

  // -----------------------------------------------------------------------
  // Checklist upload (unchanged logic)
  // -----------------------------------------------------------------------

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
        _checklistUploading = true;
        _error = null;
      });
      final uploaded = await _api.uploadChecklistBytes(
        _adminKey,
        filename: picked.name,
        bytes: picked.bytes,
      );
      if (!mounted) return;
      setState(() => _checklistUploading = false);

      if (uploaded == null) {
        setState(() => _error = _api.lastError ?? 'Ошибка загрузки файла');
        return;
      }

      setState(() {
        _checklistUrlController.text = uploaded['url'] as String? ?? '';
        _checklistUploadedFilename =
            uploaded['filename'] as String? ?? picked.name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checklistUploading = false;
        _error = 'Ошибка выбора файла: $e';
      });
    }
  }

  // -----------------------------------------------------------------------
  // Save
  // -----------------------------------------------------------------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_type == 'video') {
      final filled = _subItemForms.where((f) => f.isFilled).toList();
      if (filled.isEmpty) {
        setState(
            () => _error = 'Добавьте хотя бы один видео урок с названием');
        return;
      }
      final hasVideoNoTitle =
          _subItemForms.any((f) => !f.isFilled && f.videoUrl.isNotEmpty);
      if (hasVideoNoTitle) {
        setState(() => _error =
            'У видео уроков с загруженным видео должно быть название');
        return;
      }
    }

    if (_type == 'checklist' &&
        _checklistUrlController.text.trim().isEmpty) {
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
      'section': _section,
      'display_date': _displayDate.toIso8601String().split('T').first,
      'title': _titleController.text.trim(),
      'subtitle': _quillController == null ||
              _quillController!.document.toPlainText().trim().isEmpty
          ? null
          : jsonEncode(_quillController!.document.toDelta().toJson()),
      'sort_order': _sortOrder,
    };

    if (_type == 'checklist') {
      body['url'] = _checklistUrlController.text.trim().isEmpty
          ? null
          : _checklistUrlController.text.trim();
      body['sub_items'] = [];
    } else {
      body['url'] = null;
      body['sub_items'] = _subItemForms
          .where((f) => f.isFilled)
          .toList()
          .asMap()
          .entries
          .map((entry) {
        final f = entry.value;
        return {
          'title': f.titleController.text.trim(),
          'description': f.descriptionJson,
          'url': f.videoUrl.trim().isEmpty ? null : f.videoUrl.trim(),
          'thumbnail_url':
              f.imageUrl.trim().isEmpty ? null : f.imageUrl.trim(),
          'sort_order': entry.key,
        };
      }).toList();
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
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final anyUploading =
        _subItemForms.any((f) => f.isUploading || f.isConverting || f.isImageUploading) ||
            _checklistUploading;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_id == null ? 'Новый контент' : 'Редактировать'),
        actions: [
          if (_id != null)
            TextButton(
              onPressed: _saving || anyUploading ? null : _save,
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
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.error)),
              const SizedBox(height: 12),
            ],
            // Section badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _section == 'base'
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _section == 'base'
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _section == 'base'
                        ? Icons.school_rounded
                        : Icons.library_books_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _section == 'base'
                        ? 'Раздел: База знаний'
                        : 'Раздел: Главная',
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
              decoration:
                  const InputDecoration(labelText: 'Название урока'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Обязательно' : null,
            ),
            const SizedBox(height: 12),
            const Text('Описание урока',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            if (_quillController != null)
              _DescriptionRichEditor(
                controller: _quillController!,
                focusNode: _quillFocusNode,
              ),
            if (_quillController == null) const SizedBox(height: 220),

            // ── Checklist section ──
            if (_type == 'checklist') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _checklistUploading || _saving
                        ? null
                        : _uploadChecklist,
                    icon: _checklistUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnPrimary,
                            ),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(_checklistUploading
                        ? 'Загрузка...'
                        : 'Загрузить PDF'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _checklistUploadedFilename ??
                          (_checklistUrlController.text.trim().isEmpty
                              ? 'Файл не загружен'
                              : _checklistUrlController.text.trim()),
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

            // ── Video sub-items ──
            if (_type == 'video') ...[
              const SizedBox(height: 24),
              Text('Видео уроки',
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Добавьте видео уроки. Новый блок появится автоматически после заполнения.',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textTertiary),
              ),
              const SizedBox(height: 16),
              ..._subItemForms.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _SubItemBlock(
                    index: entry.key,
                    form: entry.value,
                    isSaving: _saving,
                    onUploadVideo: () =>
                        _uploadSubItemVideo(entry.key),
                    onRetryUpload: () =>
                        _retrySubItemVideoUpload(entry.key),
                    onUploadImage: () =>
                        _uploadSubItemImage(entry.key),
                    onRetryImageUpload: () =>
                        _retrySubItemImageUpload(entry.key),
                  ),
                );
              }),
            ],

            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving || anyUploading ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnPrimary))
                  : const Text('Сохранить'),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-item block: number header + title + rich description + video upload
// ---------------------------------------------------------------------------

class _SubItemBlock extends StatelessWidget {
  final int index;
  final _SubItemFormData form;
  final bool isSaving;
  final VoidCallback onUploadVideo;
  final VoidCallback onRetryUpload;
  final VoidCallback onUploadImage;
  final VoidCallback onRetryImageUpload;

  const _SubItemBlock({
    required this.index,
    required this.form,
    required this.isSaving,
    required this.onUploadVideo,
    required this.onRetryUpload,
    required this.onUploadImage,
    required this.onRetryImageUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.primary.withValues(alpha: 0.05),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Видео урок ${index + 1}',
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: form.titleController,
                  decoration: const InputDecoration(
                    labelText: 'Название видео урока',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Описание',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                if (form.quillController != null)
                  _DescriptionRichEditor(
                    controller: form.quillController!,
                    focusNode: form.quillFocusNode,
                    height: 140,
                  ),
                const SizedBox(height: 14),
                _VideoUploadBlock(
                  isUploading: form.isUploading,
                  isConverting: form.isConverting,
                  isSaving: isSaving,
                  uploadStatus: form.videoUploadStatus,
                  uploadProgress: form.videoUploadProgress,
                  conversionProgress: form.videoConversionProgress,
                  uploadError: form.videoUploadError,
                  uploadedFilename: form.uploadedFilename,
                  thumbnailUrl: form.thumbnailUrl,
                  urlText: form.videoUrl,
                  videoUrl: form.videoUrl,
                  onUpload: onUploadVideo,
                  onRetry: onRetryUpload,
                ),
                const SizedBox(height: 14),
                _ImageUploadBlock(
                  isUploading: form.isImageUploading,
                  isSaving: isSaving,
                  uploadStatus: form.imageUploadStatus,
                  uploadProgress: form.imageUploadProgress,
                  uploadError: form.imageUploadError,
                  uploadedFilename: form.imageUploadedFilename,
                  imageUrl: form.imageUrl,
                  onUpload: onUploadImage,
                  onRetry: onRetryImageUpload,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Video upload block with progress, success and error states
// ---------------------------------------------------------------------------

class _VideoUploadBlock extends StatelessWidget {
  final bool isUploading;
  final bool isConverting;
  final bool isSaving;
  final String uploadStatus; // idle | uploading | converting | success | error
  final double uploadProgress;
  final double conversionProgress;
  final String? uploadError;
  final String? uploadedFilename;
  final String? thumbnailUrl;
  final String urlText;
  final String? videoUrl;
  final VoidCallback onUpload;
  final VoidCallback onRetry;

  const _VideoUploadBlock({
    required this.isUploading,
    required this.isConverting,
    required this.isSaving,
    required this.uploadStatus,
    required this.uploadProgress,
    required this.conversionProgress,
    this.uploadError,
    this.uploadedFilename,
    this.thumbnailUrl,
    required this.urlText,
    this.videoUrl,
    required this.onUpload,
    required this.onRetry,
  });

  static void _openUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showUploadProgress = uploadStatus == 'uploading';
    final showConvertProgress = uploadStatus == 'converting';
    final showSuccess = uploadStatus == 'success';
    final showError = uploadStatus == 'error';
    final isBusy = isUploading || isConverting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: (isBusy || isSaving) ? null : onUpload,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnPrimary,
                      ),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(
                isBusy ? 'Загрузка...' : 'Загрузить видео',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                uploadedFilename ??
                    (urlText.isEmpty ? 'Файл не загружен' : urlText),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        // Upload progress bar
        if (showUploadProgress) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: uploadProgress,
            backgroundColor: AppColors.border,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${(uploadProgress * 100).round()}%',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Загрузка файла на сервер...',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
        // Conversion progress bar
        if (showConvertProgress) ...[
          const SizedBox(height: 12),
          // Upload complete checkmark
          Row(
            children: [
              Icon(Icons.check_circle,
                  color: AppColors.success.withValues(alpha: 0.7), size: 18),
              const SizedBox(width: 6),
              Text(
                'Файл загружен',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: conversionProgress > 0 ? conversionProgress : null,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.orange.shade700,
            ),
            minHeight: 6,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (conversionProgress > 0)
                Text(
                  '${(conversionProgress * 100).round()}%',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (conversionProgress > 0) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Оптимизация видео для приложения...',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
        // Success state with thumbnail preview
        if (showSuccess) ...[
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Clickable thumbnail preview
                if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          final url = videoUrl;
                          if (url != null && url.isNotEmpty) {
                            _openUrl(url);
                          }
                        },
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                thumbnailUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 80,
                                  height: 80,
                                  color: AppColors.surfaceSecondary,
                                  child: const Icon(Icons.videocam,
                                      color: AppColors.textTertiary, size: 32),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Icon(Icons.play_circle_fill,
                                      color: Colors.white, size: 32),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppColors.success, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Видео готово',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (uploadedFilename != null &&
                          uploadedFilename != 'index.m3u8') ...[
                        const SizedBox(height: 4),
                        Text(
                          uploadedFilename!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        // Error state
        if (showError) ...[
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        uploadError ??
                            'Ошибка загрузки. Перезагрузите страницу и попробуйте снова.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: isBusy ? null : onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Повторить загрузку'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Image upload block with progress, success and error states
// ---------------------------------------------------------------------------

class _ImageUploadBlock extends StatelessWidget {
  final bool isUploading;
  final bool isSaving;
  final String uploadStatus; // idle | uploading | success | error
  final double uploadProgress;
  final String? uploadError;
  final String? uploadedFilename;
  final String imageUrl;
  final VoidCallback onUpload;
  final VoidCallback onRetry;

  const _ImageUploadBlock({
    required this.isUploading,
    required this.isSaving,
    required this.uploadStatus,
    required this.uploadProgress,
    this.uploadError,
    this.uploadedFilename,
    required this.imageUrl,
    required this.onUpload,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final showUploadProgress = uploadStatus == 'uploading';
    final showSuccess = uploadStatus == 'success';
    final showError = uploadStatus == 'error';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: (isUploading || isSaving) ? null : onUpload,
              icon: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnPrimary,
                      ),
                    )
                  : const Icon(Icons.image_outlined),
              label: Text(
                isUploading ? 'Загрузка...' : 'Загрузить фото',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                uploadedFilename ??
                    (imageUrl.isEmpty ? 'Фото не загружено' : imageUrl),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        if (showUploadProgress) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: uploadProgress,
            backgroundColor: AppColors.border,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${(uploadProgress * 100).round()}%',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Загрузка фото на сервер...',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
        if (showSuccess) ...[
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (imageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: AppColors.surfaceSecondary,
                          child: const Icon(Icons.image,
                              color: AppColors.textTertiary, size: 32),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppColors.success, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Фото загружено',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (uploadedFilename != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          uploadedFilename!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (showError) ...[
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        uploadError ?? 'Ошибка загрузки фото.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: isUploading ? null : onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Повторить загрузку'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Rich text editor for descriptions with toolbar and link dialog
// ---------------------------------------------------------------------------

class _DescriptionRichEditor extends StatefulWidget {
  final QuillController controller;
  final FocusNode focusNode;
  final double height;

  const _DescriptionRichEditor({
    required this.controller,
    required this.focusNode,
    this.height = 200,
  });

  @override
  State<_DescriptionRichEditor> createState() =>
      _DescriptionRichEditorState();
}

class _DescriptionRichEditorState extends State<_DescriptionRichEditor> {
  void _showLinkDialog() {
    final sel = widget.controller.selection;
    final len = sel.end - sel.start;
    final text = len > 0
        ? widget.controller.document.getPlainText(sel.start, len).trim()
        : '';
    final urlController = TextEditingController();
    final textController = TextEditingController(text: text);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Добавить ссылку'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Текст ссылки',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  widget.controller.formatSelection(LinkAttribute(url));
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    ).then((_) {
      urlController.dispose();
      textController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuillSimpleToolbar(
            controller: widget.controller,
            config: QuillSimpleToolbarConfig(
              showFontFamily: false,
              showFontSize: false,
              showUnderLineButton: false,
              showStrikeThrough: false,
              showInlineCode: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: false,
              showAlignmentButtons: false,
              showHeaderStyle: false,
              showListNumbers: false,
              showListCheck: false,
              showCodeBlock: false,
              showIndent: false,
              showUndo: false,
              showRedo: false,
              showSearchButton: false,
              showLink: false,
              showSubscript: false,
              showSuperscript: false,
              customButtons: [
                QuillToolbarCustomButtonOptions(
                  icon: const Icon(Icons.link),
                  tooltip: 'Добавить ссылку',
                  onPressed: _showLinkDialog,
                ),
              ],
            ),
          ),
          Container(
            height: widget.height,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: QuillEditor.basic(
              controller: widget.controller,
              focusNode: widget.focusNode,
              config: QuillEditorConfig(
                placeholder: 'Введите описание...',
                padding: EdgeInsets.zero,
                customStyles: DefaultStyles(
                  link: TextStyle(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
