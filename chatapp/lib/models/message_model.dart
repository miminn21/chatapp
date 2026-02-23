class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String type; // text, image, video, audio, file, system
  String content;
  final String? replyTo;
  final String? replyContent;
  final String? replySenderName;
  final String? senderName;
  final String? senderAvatar;
  final DateTime createdAt;
  String status; // sent, delivered, read
  bool isDeleted;
  bool isEdited;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.content,
    this.replyTo,
    this.replyContent,
    this.replySenderName,
    this.senderName,
    this.senderAvatar,
    required this.createdAt,
    this.status = 'sent',
    this.isDeleted = false,
    this.isEdited = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'] ?? '',
        conversationId: json['conversation_id'] ?? '',
        senderId: json['sender_id'] ?? '',
        type: json['type'] ?? 'text',
        content: json['content'] ?? '',
        replyTo: json['reply_to'],
        replyContent: json['reply_content'],
        replySenderName: json['reply_sender_name'],
        senderName: json['sender_name'],
        senderAvatar: json['sender_avatar'],
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'])?.toLocal() ?? DateTime.now()
            : DateTime.now(),
        status: json['status'] ?? 'sent',
        isDeleted: json['is_deleted'] == true || json['deleted_at'] != null,
        isEdited: json['is_edited'] == true || json['edited_at'] != null,
      );

  bool get isSystem => type == 'system';
  bool get isImage => type == 'image';
  bool get isFile => type == 'file' || type == 'video' || type == 'audio';
}
