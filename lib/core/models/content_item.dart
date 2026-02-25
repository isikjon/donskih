class ContentSubItemDto {
  final String id;
  final String title;
  final String? duration;
  final int sortOrder;

  ContentSubItemDto({
    required this.id,
    required this.title,
    this.duration,
    this.sortOrder = 0,
  });

  factory ContentSubItemDto.fromJson(Map<String, dynamic> json) {
    return ContentSubItemDto(
      id: json['id'] as String,
      title: json['title'] as String,
      duration: json['duration'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class ContentItemDto {
  final String id;
  final String type; // video | checklist
  final String displayDate; // YYYY-MM-DD
  final String title;
  final String? subtitle;
  final int sortOrder;
  final String? url;
  final List<ContentSubItemDto> subItems;

  ContentItemDto({
    required this.id,
    required this.type,
    required this.displayDate,
    required this.title,
    this.subtitle,
    this.sortOrder = 0,
    this.url,
    this.subItems = const [],
  });

  factory ContentItemDto.fromJson(Map<String, dynamic> json) {
    final subList = json['sub_items'] as List<dynamic>? ?? [];
    return ContentItemDto(
      id: json['id'] as String,
      type: json['type'] as String,
      displayDate: json['display_date'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      url: json['url'] as String?,
      subItems: subList
          .map((e) => ContentSubItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isVideo => type == 'video';
  bool get isChecklist => type == 'checklist';

  /// "2025-02-06" → "06 февраля"
  static String formatDisplayDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    final day = parts[2];
    final month = (int.tryParse(parts[1]) ?? 1) - 1;
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    if (month < 0 || month >= months.length) return isoDate;
    return '$day ${months[month]}';
  }
}
