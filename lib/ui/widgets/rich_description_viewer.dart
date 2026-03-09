import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/content_item.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

// ---------------------------------------------------------------------------
// Парсинг таймкодов mm:ss или hh:mm:ss в секунды
// ---------------------------------------------------------------------------

/// Регулярное выражение для таймкодов: 00:30, 01:15, 01:02:30
final RegExp timestampRegex = RegExp(r'\b(\d{1,2}):(\d{2})(?::(\d{2}))?\b');

/// Преобразует строку таймкода в секунды.
/// 00:30 → 30, 01:30 → 90, 01:02:30 → 3750.
/// Возвращает null при невалидной строке.
int? parseTimestampToSeconds(String s) {
  final m = timestampRegex.firstMatch(s);
  if (m == null) return null;
  final first = int.tryParse(m.group(1) ?? '');
  final second = int.tryParse(m.group(2) ?? '');
  final third = m.group(3);
  if (first == null || second == null) return null;
  if (third != null) {
    final h = int.tryParse(third);
    if (h == null) return null;
    return first * 3600 + second * 60 + h;
  }
  return first * 60 + second;
}

/// Показывает описание урока: если subtitle — Delta JSON (из админки Quill),
/// рендерит с форматированием (жирный, курсив, цитаты, ссылки); иначе — обычный текст с кликабельными URL и таймкодами.
class RichDescriptionViewer extends StatefulWidget {
  final String? subtitle;
  final TextStyle? textStyle;
  final int? maxLines;
  /// При просмотре урока с видео: по нажатию на таймкод перематывает видео на указанное время.
  final void Function(int seconds)? onTimestampTap;

  const RichDescriptionViewer({
    super.key,
    this.subtitle,
    this.textStyle,
    this.maxLines,
    this.onTimestampTap,
  });

  @override
  State<RichDescriptionViewer> createState() => _RichDescriptionViewerState();
}

class _RichDescriptionViewerState extends State<RichDescriptionViewer> {
  QuillController? _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant RichDescriptionViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subtitle != widget.subtitle) {
      _controller?.dispose();
      _controller = null;
      _initController();
    }
  }

  void _initController() {
    final s = widget.subtitle?.trim();
    if (s == null || s.isEmpty) return;
    Document doc;
    if (s.startsWith('[')) {
      try {
        doc = Document.fromJson(jsonDecode(s) as List<dynamic>);
      } catch (_) {
        doc = Document.fromJson(<Map<String, dynamic>>[{'insert': '$s\n'}]);
      }
    } else {
      doc = Document.fromJson(<Map<String, dynamic>>[{'insert': '$s\n'}]);
    }
    _controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subtitle?.trim();
    if (s == null || s.isEmpty) return const SizedBox.shrink();

    // Если нужны кликабельные таймкоды (например на экране видео) — показываем plain text с парсингом таймкодов и URL
    if (widget.onTimestampTap != null) {
      final plain = s.startsWith('[')
          ? (ContentItemDto.subtitleToPlainText(s) ?? s)
          : s;
      return _LinkedTextWithTimestamps(
        text: plain,
        style: widget.textStyle ?? AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        maxLines: widget.maxLines,
        overflow: widget.maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
        onTimestampTap: widget.onTimestampTap!,
      );
    }

    if (_controller != null) {
      return QuillEditor.basic(
        controller: _controller!,
        config: QuillEditorConfig(
          placeholder: '',
          padding: EdgeInsets.zero,
          scrollable: false,
          showCursor: false,
          enableInteractiveSelection: false,
          customStyles: DefaultStyles(
            link: TextStyle(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    return _LinkedText(
      text: s,
      style: widget.textStyle ?? AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      maxLines: widget.maxLines,
      overflow: widget.maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }
}

/// Текст с кликабельными URL и таймкодами (mm:ss или hh:mm:ss). Для таймкодов вызывается [onTimestampTap].
class _LinkedTextWithTimestamps extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final void Function(int seconds) onTimestampTap;

  const _LinkedTextWithTimestamps({
    required this.text,
    required this.onTimestampTap,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  State<_LinkedTextWithTimestamps> createState() => _LinkedTextWithTimestampsState();
}

class _LinkedTextWithTimestampsState extends State<_LinkedTextWithTimestamps> {
  static final _urlRegex = RegExp(
    r'https?://[^\s<>\[\]{}|\\^`"]+',
    caseSensitive: false,
  );

  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = widget.text;
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;

    // Собираем все совпадения (URL и таймкоды) с позициями
    final matches = <({int start, int end, String type, String value})>[];
    for (final m in _urlRegex.allMatches(text)) {
      matches.add((start: m.start, end: m.end, type: 'url', value: m.group(0)!));
    }
    for (final m in timestampRegex.allMatches(text)) {
      final value = m.group(0)!;
      if (parseTimestampToSeconds(value) != null) {
        matches.add((start: m.start, end: m.end, type: 'ts', value: value));
      }
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    // Убираем перекрытия: оставляем первое вхождение
    int lastEnd = 0;
    final merged = <({int start, int end, String type, String value})>[];
    for (final m in matches) {
      if (m.start >= lastEnd) {
        merged.add(m);
        lastEnd = m.end;
      }
    }

    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final m in merged) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      if (m.type == 'url') {
        final rec = TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.tryParse(m.value);
            if (uri != null) {
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
              }
            }
          };
        _recognizers.add(rec);
        spans.add(TextSpan(
          text: m.value,
          style: TextStyle(
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          ),
          recognizer: rec,
        ));
      } else {
        final seconds = parseTimestampToSeconds(m.value)!;
        final rec = TapGestureRecognizer()
          ..onTap = () => widget.onTimestampTap(seconds);
        _recognizers.add(rec);
        spans.add(TextSpan(
          text: m.value,
          style: TextStyle(
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          ),
          recognizer: rec,
        ));
      }
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: RichText(
        text: TextSpan(style: baseStyle, children: spans),
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      ),
    );
  }
}

/// Текст с кликабельными http(s) ссылками.
class _LinkedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  const _LinkedText({
    required this.text,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  State<_LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<_LinkedText> {
  static final _urlRegex = RegExp(
    r'https?://[^\s<>\[\]{}|\\^`"]+',
    caseSensitive: false,
  );

  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = widget.text;
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final spans = <InlineSpan>[];
    int cursor = 0;

    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final url = match.group(0)!;
      final rec = TapGestureRecognizer()..onTap = () => _launch(url);
      _recognizers.add(rec);
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: AppColors.primary,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primary,
        ),
        recognizer: rec,
      ));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
