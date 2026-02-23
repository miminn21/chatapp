import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:shared_preferences/shared_preferences.dart';
import '../app_config.dart';
import '../screens/call/call_screen.dart';
import '../screens/call/incoming_call_screen.dart';

class SocketProvider extends ChangeNotifier {
  socket_io.Socket? _socket;
  bool _connected = false;

  bool get connected => _connected;
  socket_io.Socket? get socket => _socket;

  // Navigation context (set by main app widget)
  BuildContext? navigatorContext;

  // Callback hooks for chat screen
  Function(Map<String, dynamic>)? onNewMessage;
  Function(Map<String, dynamic>)? onTyping;
  Function(Map<String, dynamic>)? onMessageRead;
  Function(Map<String, dynamic>)? onUserOnline;
  Function(Map<String, dynamic>)? onUserOffline;
  Function(Map<String, dynamic>)? onMessageStatusUpdate;

  Future<void> connect() async {
    if (_connected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    _socket = socket_io.io(
      AppConfig.socketUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _connected = true;
      notifyListeners();
      debugPrint('Socket connected');
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      notifyListeners();
      debugPrint('Socket disconnected');
    });

    _socket!.on('new_message', (data) {
      if (data is Map<String, dynamic>) {
        onNewMessage?.call(data);
      }
    });

    _socket!.on('typing', (data) {
      if (data is Map<String, dynamic>) {
        onTyping?.call(data);
      }
    });

    _socket!.on('message_read', (data) {
      if (data is Map<String, dynamic>) {
        onMessageRead?.call(data);
      }
    });

    // Delivered status update from server
    _socket!.on('message_status_update', (data) {
      if (data is Map<String, dynamic>) {
        onMessageStatusUpdate?.call(data);
      }
    });

    _socket!.on('user_online', (data) {
      if (data is Map<String, dynamic>) {
        onUserOnline?.call(data);
      }
    });

    _socket!.on('user_offline', (data) {
      if (data is Map<String, dynamic>) {
        onUserOffline?.call(data);
      }
    });

    // ── Call Signalling ──────────────────────────────────────────────────
    _socket!.on('incoming_call', (data) {
      if (data is! Map<String, dynamic>) return;
      final ctx = navigatorContext;
      if (ctx == null || !ctx.mounted) return;
      Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callerName: data['caller_name'] ?? 'Unknown',
          callerAvatar: data['caller_avatar'] ?? '',
          channelName: data['channel_name'] ?? '',
          isVideo: data['is_video'] == true,
          onAccept: () {
            _socket?.emit('accept_call', {
              'caller_id': data['caller_id'],
              'channel_name': data['channel_name'],
            });
            Navigator.of(ctx).push(MaterialPageRoute(
              builder: (_) => CallScreen(
                channelName: data['channel_name'] ?? '',
                callerName: data['caller_name'] ?? 'Unknown',
                isVideo: data['is_video'] == true,
                isCaller: false,
              ),
            ));
          },
          onReject: () {
            _socket?.emit('reject_call', {'caller_id': data['caller_id']});
          },
        ),
      ));
    });

    _socket!.on('call_accepted', (data) {
      // Caller's side: callee accepted, open call screen
      // This is handled directly in chat_screen via a callback
      onCallAccepted?.call(data is Map<String, dynamic> ? data : {});
    });

    _socket!.on('call_rejected', (_) {
      final ctx = navigatorContext;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Panggilan ditolak'),
          backgroundColor: Colors.red,
        ),
      );
      onCallRejected?.call();
    });

    _socket!.on('call_ended', (_) {
      onCallEnded?.call();
    });
  }

  // Call signal callbacks (set by chat_screen)
  Function(Map<String, dynamic>)? onCallAccepted;
  VoidCallback? onCallRejected;
  VoidCallback? onCallEnded;

  void sendMessage(Map<String, dynamic> data) {
    _socket?.emit('send_message', data);
  }

  void sendTyping(String conversationId, bool isTyping) {
    _socket?.emit('typing', {
      'conversation_id': conversationId,
      'is_typing': isTyping,
    });
  }

  void markRead(String messageId, String conversationId) {
    _socket?.emit('message_read', {
      'message_id': messageId,
      'conversation_id': conversationId,
    });
  }

  void joinRoom(String conversationId) {
    _socket?.emit('join_room', conversationId);
  }

  // ── Call methods ─────────────────────────────────────────────────────────────
  void callUser({
    required String targetUserId,
    required String channelName,
    required String callerName,
    required String callerAvatar,
    required bool isVideo,
  }) {
    _socket?.emit('call_user', {
      'target_user_id': targetUserId,
      'channel_name': channelName,
      'caller_name': callerName,
      'caller_avatar': callerAvatar,
      'is_video': isVideo,
    });
  }

  void endCall(String targetUserId) {
    _socket?.emit('end_call', {'target_user_id': targetUserId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
    notifyListeners();
  }
}
