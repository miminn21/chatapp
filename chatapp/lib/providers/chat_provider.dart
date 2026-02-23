import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class ChatProvider extends ChangeNotifier {
  List<ConversationModel> _conversations = [];
  final Map<String, List<MessageModel>> _messages = {};
  final Map<String, bool> _typingMap = {};
  bool _loading = false;

  List<ConversationModel> get conversations => _conversations;
  bool get loading => _loading;

  List<MessageModel> getMessages(String convId) => _messages[convId] ?? [];
  bool isTyping(String convId) => _typingMap[convId] ?? false;

  void deleteMessageLocal(String convId, String messageId) {
    if (!_messages.containsKey(convId)) return;
    final idx = _messages[convId]!.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      _messages[convId]![idx].isDeleted = true;
      _messages[convId]![idx].content = 'Pesan dihapus';
    }
    notifyListeners();
  }

  /// Allows screens to trigger a rebuild after mutating message data in-place.
  void notifyListenersPublic() => notifyListeners();

  Future<void> loadConversations() async {
    _loading = true;
    notifyListeners();
    try {
      final resp = await apiService.get('/conversations');
      if (resp.data['success'] == true) {
        _conversations = (resp.data['data'] as List)
            .map((e) => ConversationModel.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('loadConversations error: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMessages(String convId, {String? before}) async {
    try {
      final resp = await apiService.get(
        '/conversations/$convId/messages',
        params: {if (before != null) 'before': before, 'limit': '50'},
      );
      if (resp.data['success'] == true) {
        final msgs = (resp.data['data'] as List)
            .map((e) => MessageModel.fromJson(e))
            .toList();
        if (before != null) {
          _messages[convId] = [...msgs, ...(_messages[convId] ?? [])];
        } else {
          _messages[convId] = msgs;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('loadMessages error: $e');
    }
  }

  Future<String?> createOrGetDM(String otherUserId) async {
    try {
      final resp = await apiService.post(
        '/conversations/dm', // ← fixed endpoint
        data: {'other_user_id': otherUserId},
      );
      if (resp.data['success'] == true) {
        final convId = resp.data['data']['id'] as String;
        await loadConversations();
        return convId;
      }
    } catch (e) {
      debugPrint('createDM error: $e');
    }
    return null;
  }

  Future<String?> createGroup({
    required String name,
    String? description,
    required List<String> memberIds,
  }) async {
    try {
      final resp = await apiService.post(
        '/groups',
        data: {
          'name': name,
          'description': description ?? '',
          'member_ids': memberIds,
        },
      );
      if (resp.data['success'] == true) {
        final convId = resp.data['data']['conversation_id'] as String;
        await loadConversations();
        return convId;
      }
    } catch (e) {
      debugPrint('createGroup error: $e');
    }
    return null;
  }

  // Called from socket new_message event
  void onNewMessage(Map<String, dynamic> data, {String? myUserId}) {
    final msg = MessageModel.fromJson(data);
    final convId = msg.conversationId;
    final isOwn = myUserId != null && msg.senderId == myUserId;

    // Add to message list if loaded
    if (_messages.containsKey(convId)) {
      _messages[convId]!.add(msg);
    }

    // Update conversation last message preview
    final idx = _conversations.indexWhere((c) => c.id == convId);
    if (idx != -1) {
      final updated = _conversations[idx].copyWith(
        lastMessage: msg.content,
        lastMessageAt: msg.createdAt,
        lastMessageType: msg.type,
        unreadCount: isOwn
            ? _conversations[idx].unreadCount
            : _conversations[idx].unreadCount + 1,
      );
      _conversations.removeAt(idx);
      _conversations.insert(0, updated);
    } else {
      loadConversations();
    }
    notifyListeners();
  }

  // Update message read/delivered status from socket event
  void updateMessageStatus(String messageId, String newStatus) {
    for (final msgs in _messages.values) {
      final idx = msgs.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        msgs[idx].status = newStatus;
        notifyListeners();
        break;
      }
    }
  }

  void onTyping(Map<String, dynamic> data) {
    final convId = data['conversation_id'] as String? ?? '';
    final isTyping = data['is_typing'] as bool? ?? false;
    _typingMap[convId] = isTyping;
    notifyListeners();
  }

  void clearUnread(String convId) {
    final idx = _conversations.indexWhere((c) => c.id == convId);
    if (idx != -1) {
      _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  void updateUserOnlineStatus(String userId, bool isOnline) {
    _conversations = _conversations.map((c) {
      if (c.type == 'dm' && c.otherUser?.id == userId) {
        return c.copyWith(otherUser: c.otherUser?.copyWith(isOnline: isOnline));
      }
      return c;
    }).toList();
    notifyListeners();
  }
}
