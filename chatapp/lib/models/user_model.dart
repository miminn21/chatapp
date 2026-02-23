class UserModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? avatar;
  final String? coverPhoto;
  final String statusMessage;
  final String? bio;
  final bool isOnline;
  final DateTime? lastSeen;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.avatar,
    this.coverPhoto,
    this.statusMessage = 'Hey there! I am using ChatApp.',
    this.bio,
    this.isOnline = false,
    this.lastSeen,
  });

  String? get avatarUrl => _cleanUrl(avatar);
  String? get coverUrl => _cleanUrl(coverPhoto);

  static String? _cleanUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('data:')) return raw;
    if (raw.startsWith('http')) return raw;
    return null;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        phone: json['phone'] ?? '',
        email: json['email'],
        avatar: json['avatar'],
        coverPhoto: json['cover_photo'],
        statusMessage:
            json['status_message'] ?? 'Hey there! I am using ChatApp.',
        bio: json['bio'],
        isOnline: json['is_online'] == 1 || json['is_online'] == true,
        lastSeen: json['last_seen'] != null
            ? DateTime.tryParse(json['last_seen'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'avatar': avatar,
        'cover_photo': coverPhoto,
        'status_message': statusMessage,
        'bio': bio,
        'is_online': isOnline,
        'last_seen': lastSeen?.toIso8601String(),
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? avatar,
    String? coverPhoto,
    String? statusMessage,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        phone: phone,
        email: email ?? this.email,
        avatar: avatar ?? this.avatar,
        coverPhoto: coverPhoto ?? this.coverPhoto,
        statusMessage: statusMessage ?? this.statusMessage,
        bio: bio ?? this.bio,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}
