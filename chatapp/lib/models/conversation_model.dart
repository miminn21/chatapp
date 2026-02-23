import '../services/api_service.dart';
import 'user_model.dart';

class ConversationModel {
  final String id;
  final String type; // dm or group
  final DateTime updatedAt;

  // For DM
  final UserModel? otherUser;

  // For group
  final String? groupName;
  final String? groupAvatar;
  final String? groupDescription;
  final List<UserModel> members;

  // Last message preview
  final String? lastMessage;
  final String? lastMessageType;
  final DateTime? lastMessageAt;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.type,
    required this.updatedAt,
    this.otherUser,
    this.groupName,
    this.groupAvatar,
    this.groupDescription,
    this.members = const [],
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  String get displayName =>
      type == 'dm' ? (otherUser?.name ?? 'Unknown') : (groupName ?? 'Group');
  String? get displayAvatar =>
      type == 'dm' ? otherUser?.avatarUrl : apiService.getMediaUrl(groupAvatar);
  bool get isGroup => type == 'group';
  bool get isOnline => type == 'dm' && (otherUser?.isOnline ?? false);

  factory ConversationModel.fromJson(Map<String, dynamic> json) =>
      ConversationModel(
        id: json['id'] ?? '',
        type: json['type'] ?? 'dm',
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'])?.toLocal() ?? DateTime.now()
            : DateTime.now(),
        otherUser: json['other_user'] != null
            ? UserModel.fromJson(json['other_user'])
            : null,
        groupName: json['group_name'],
        groupAvatar: json['group_avatar'],
        groupDescription: json['group_description'],
        members: json['members'] != null
            ? (json['members'] as List)
                .map((m) => UserModel.fromJson(m))
                .toList()
            : [],
        lastMessage: json['last_message'],
        lastMessageType: json['last_message_type'],
        lastMessageAt: json['last_message_at'] != null
            ? DateTime.tryParse(json['last_message_at'])?.toLocal()
            : null,
        unreadCount: int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0,
      );

  ConversationModel copyWith({
    UserModel? otherUser,
    int? unreadCount,
    String? lastMessage,
    String? lastMessageType,
    DateTime? lastMessageAt,
  }) =>
      ConversationModel(
        id: id,
        type: type,
        updatedAt: updatedAt,
        otherUser: otherUser ?? this.otherUser,
        groupName: groupName,
        groupAvatar: groupAvatar,
        groupDescription: groupDescription,
        members: members,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageType: lastMessageType ?? this.lastMessageType,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}
