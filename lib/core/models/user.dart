class User {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? username;
  final String? bio;
  final DateTime? joinedAt;
  final bool? isOnline;
  final DateTime? lastSeenAt;

  const User({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.username,
    this.bio,
    this.joinedAt,
    this.isOnline,
    this.lastSeenAt,
  });

  User copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? username,
    String? bio,
    DateTime? joinedAt,
    bool? isOnline,
    DateTime? lastSeenAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      joinedAt: joinedAt ?? this.joinedAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  factory User.fromPublicJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as String),
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String)
          : 'Пользователь',
      avatarUrl: json['avatar_url'] as String?,
      username: json['username'] as String?,
      bio: json['bio'] as String?,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String).toLocal()
          : null,
      isOnline: json['is_online'] as bool?,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String).toLocal()
          : null,
    );
  }
}

