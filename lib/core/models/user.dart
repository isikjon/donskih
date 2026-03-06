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
    final rawId = json['id'];
    final id = rawId is String ? rawId : rawId?.toString() ?? '';

    final rawJoined = json['joined_at'];
    DateTime? joinedAt;
    if (rawJoined != null) {
      try {
        joinedAt = DateTime.parse(rawJoined.toString()).toLocal();
      } catch (_) {}
    }

    final rawLastSeen = json['last_seen_at'];
    DateTime? lastSeenAt;
    if (rawLastSeen != null) {
      try {
        lastSeenAt = DateTime.parse(rawLastSeen.toString()).toLocal();
      } catch (_) {}
    }

    return User(
      id: id,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String)
          : 'Пользователь',
      avatarUrl: json['avatar_url'] as String?,
      username: json['username'] as String?,
      bio: json['bio'] as String?,
      joinedAt: joinedAt,
      isOnline: json['is_online'] as bool?,
      lastSeenAt: lastSeenAt,
    );
  }
}

