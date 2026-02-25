class ChatMessage {
  final String id;
  final String userId;
  final String senderName;
  final String? senderPhotoUrl;
  final String? text;
  final String? imageUrl;
  final bool isDeleted;
  final bool isEdited;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.userId,
    required this.senderName,
    this.senderPhotoUrl,
    this.text,
    this.imageUrl,
    required this.isDeleted,
    required this.isEdited,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      senderName: json['sender_name'] as String? ?? 'Участник',
      senderPhotoUrl: json['sender_photo_url'] as String?,
      text: json['text'] as String?,
      imageUrl: json['image_url'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      isEdited: json['is_edited'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  ChatMessage copyWith({
    String? id,
    String? userId,
    String? senderName,
    String? senderPhotoUrl,
    String? text,
    String? imageUrl,
    bool? isDeleted,
    bool? isEdited,
    DateTime? createdAt,
    bool clearText = false,
    bool clearImageUrl = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      text: clearText ? null : (text ?? this.text),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      isDeleted: isDeleted ?? this.isDeleted,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get timeFormatted {
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
