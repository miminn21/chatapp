import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/conversation_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/socket_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import '../../screens/profile/profile_screen.dart' show formatLastSeen;
import '../../screens/call/call_screen.dart';
import 'group_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;
  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;
  bool _loadingMore = false;
  MessageModel? _replyTo;
  // Edit mode
  MessageModel? _editingMsg;

  // Voice recording
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordTimer;
  int _recordDuration = 0;
  bool _isCancelling = false;

  ConversationModel get conv => widget.conversation;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndMarkRead();
      context.read<SocketProvider>().joinRoom(conv.id);
      _hookSocket();
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Infinite scroll: load more when user scrolls to top ─────────
  void _onScroll() {
    if (_scrollCtrl.position.pixels <= 60 && !_loadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final chat = context.read<ChatProvider>();
    final msgs = chat.getMessages(conv.id);
    if (msgs.isEmpty || _loadingMore) return;
    setState(() => _loadingMore = true);
    final oldest = msgs.first.createdAt.toIso8601String();
    await chat.loadMessages(conv.id, before: oldest);
    setState(() => _loadingMore = false);
  }

  Future<void> _loadAndMarkRead() async {
    final chat = context.read<ChatProvider>();
    final socket = context.read<SocketProvider>();
    final me = context.read<AuthProvider>().user;
    chat.clearUnread(conv.id);
    await chat.loadMessages(conv.id);
    final msgs = chat.getMessages(conv.id);
    for (final msg in msgs) {
      if (msg.senderId != me?.id && msg.status != 'read') {
        socket.markRead(msg.id, conv.id);
      }
    }
    _scrollToBottom();
  }

  void _hookSocket() {
    final socket = context.read<SocketProvider>();
    final me = context.read<AuthProvider>().user;
    final chat = context.read<ChatProvider>();
    final prev = socket.onNewMessage;
    socket.onNewMessage = (data) {
      prev?.call(data);
      final msg = MessageModel.fromJson(data);
      if (msg.conversationId == conv.id && msg.senderId != me?.id) {
        socket.markRead(msg.id, conv.id);
        chat.updateMessageStatus(msg.id, 'read');
      }
      if (mounted) _scrollToBottom();
    };
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Edit message ─────────────────────────────────────────────────
  Future<void> _editMessage(MessageModel msg, String newContent) async {
    final messenger = ScaffoldMessenger.of(context);
    final chat = context.read<ChatProvider>();
    try {
      final resp = await apiService
          .patch('/messages/${msg.id}', data: {'content': newContent});
      if (resp.data['success'] == true) {
        msg.content = newContent;
        msg.isEdited = true;
        chat.notifyListenersPublic();
      } else {
        messenger.showSnackBar(
            SnackBar(content: Text(resp.data['message'] ?? 'Gagal edit')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal edit: $e')));
    }
  }

  void _startEdit(MessageModel msg) {
    setState(() {
      _editingMsg = msg;
      _textCtrl.text = msg.content;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMsg = null;
      _textCtrl.clear();
    });
  }

  Future<void> _submitEdit() async {
    final newContent = _textCtrl.text.trim();
    if (newContent.isEmpty || _editingMsg == null) return;
    final msg = _editingMsg!;
    setState(() {
      _editingMsg = null;
      _textCtrl.clear();
    });
    await _editMessage(msg, newContent);
  }

  // ── Delete message ────────────────────────────────────────────────
  Future<void> _deleteMessage(MessageModel msg) async {
    final messenger = ScaffoldMessenger.of(context);
    final chat = context.read<ChatProvider>();
    try {
      final resp = await apiService.delete('/messages/${msg.id}');
      if (resp.data['success'] == true) {
        chat.deleteMessageLocal(conv.id, msg.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Pesan dihapus')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal hapus: $e')),
      );
    }
  }

  void _showMessageOptions(BuildContext ctx, MessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Balas'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyTo = msg);
              },
            ),
            if (isMe && !msg.isDeleted) ...[
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                title: const Text('Edit', style: TextStyle(color: Colors.blue)),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEdit(msg);
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Hapus', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(msg);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Send text ─────────────────────────────────────────────────────
  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _textCtrl.clear();

    context.read<SocketProvider>().sendMessage({
      'conversation_id': conv.id,
      'content': text,
      'type': 'text',
      if (_replyTo != null) 'reply_to': _replyTo!.id,
    });
    setState(() {
      _replyTo = null;
      _isSending = false;
    });
    _scrollToBottom();
  }

  // ── Send image ────────────────────────────────────────────────────
  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;
    try {
      final formData = FormData.fromMap({
        'type': 'image',
        'file': await MultipartFile.fromFile(
          picked.path,
          filename: picked.name,
        ),
      });
      final resp = await apiService.postForm(
        '/conversations/${conv.id}/messages',
        formData,
      );
      if (resp.data['success'] == true && mounted) {
        final me = context.read<AuthProvider>().user;
        context.read<ChatProvider>().onNewMessage(
              resp.data['data'] as Map<String, dynamic>,
              myUserId: me?.id,
            );
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Send image error: $e');
    }
  }

  // ── Voice Recording Logic ──────────────────────────────────────────
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/rn_${DateTime.now().millisecondsSinceEpoch}.m4a';

        const config = RecordConfig();
        await _audioRecorder.start(config, path: path);

        setState(() {
          _isRecording = true;
          _recordingPath = path;
          _recordDuration = 0;
          _isCancelling = false;
        });

        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDuration++;
          });
        });
      }
    } catch (e) {
      debugPrint('Record start error: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (!_isCancelling && path != null) {
        _sendVoiceMessage(path);
      }
    } catch (e) {
      debugPrint('Record stop error: $e');
    }
  }

  void _updateRecordingStatus(Offset localPos) {
    if (localPos.dx < -80) {
      if (!_isCancelling) setState(() => _isCancelling = true);
    } else {
      if (_isCancelling) setState(() => _isCancelling = false);
    }
  }

  Future<void> _sendVoiceMessage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;

      final formData = FormData.fromMap({
        'type': 'audio',
        'file': await MultipartFile.fromFile(
          path,
          filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        ),
      });

      final resp = await apiService.postForm(
        '/conversations/${conv.id}/messages',
        formData,
      );

      if (resp.data['success'] == true && mounted) {
        final me = context.read<AuthProvider>().user;
        context.read<ChatProvider>().onNewMessage(
              resp.data['data'] as Map<String, dynamic>,
              myUserId: me?.id,
            );
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Send voice error: $e');
    }
  }

  // ── Start a voice/video call ──────────────────────────────────────
  void _startCall({required bool isVideo}) {
    final socket = context.read<SocketProvider>();
    final me = context.read<AuthProvider>().user!;
    final other = conv.otherUser;
    if (other == null) return;

    socket.onCallAccepted = (data) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            channelName: conv.id,
            callerName: other.name,
            isVideo: isVideo,
            isCaller: true,
          ),
        ),
      );
      socket.onCallAccepted = null;
    };
    socket.onCallRejected = () {
      socket.onCallRejected = null;
    };

    socket.callUser(
      targetUserId: other.id,
      channelName: conv.id,
      callerName: me.name,
      callerAvatar: me.avatar ?? '',
      isVideo: isVideo,
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(isVideo
            ? '\u{1F4F9} Memanggil ${other.name}...'
            : '\u{1F4DE} Memanggil ${other.name}...'),
        duration: const Duration(seconds: 30),
        action: SnackBarAction(
          label: 'Batalkan',
          onPressed: () {
            socket.endCall(other.id);
            socket.onCallAccepted = null;
            messenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // ── AppBar subtitle: online / last seen / group member count ─────
  String _buildSubtitle(bool isTyping) {
    if (isTyping) return 'Mengetik...';
    if (conv.isGroup) return '${conv.members.length} anggota';
    if (conv.isOnline) return 'Online';
    return formatLastSeen(conv.otherUser?.lastSeen);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user!;
    final messages = context.watch<ChatProvider>().getMessages(conv.id);
    final isTyping = context.watch<ChatProvider>().isTyping(conv.id);

    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        titleSpacing: 0,
        leading: const BackButton(color: Colors.white),
        title: InkWell(
          onTap: () {
            if (conv.isGroup) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupInfoScreen(conversation: conv),
                ),
              );
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white30,
                backgroundImage:
                    conv.displayAvatar != null && conv.displayAvatar!.isNotEmpty
                        ? NetworkImage(conv.displayAvatar!)
                        : null,
                child:
                    (conv.displayAvatar == null || conv.displayAvatar!.isEmpty)
                        ? Text(
                            conv.displayName.isNotEmpty
                                ? conv.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conv.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _buildSubtitle(isTyping),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!conv.isGroup) ...[
            IconButton(
              icon: const Icon(Icons.videocam, color: Colors.white),
              tooltip: 'Video Call',
              onPressed: () => _startCall(isVideo: true),
            ),
            IconButton(
              icon: const Icon(Icons.call, color: Colors.white),
              tooltip: 'Voice Call',
              onPressed: () => _startCall(isVideo: false),
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) {
              if (val == 'info' && conv.isGroup) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupInfoScreen(conversation: conv),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              if (conv.isGroup)
                const PopupMenuItem(
                  value: 'info',
                  child: Text('Info Grup'),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Load more indicator
          if (_loadingMore)
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: AppTheme.primaryGreen,
            ),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final msg = messages[i];
                final isMe = msg.senderId == me.id;
                return MessageBubble(
                  msg: msg,
                  isMe: isMe,
                  showSender: conv.isGroup && !isMe,
                  onSwipe: () => setState(() => _replyTo = msg),
                  onLongPress: () => _showMessageOptions(context, msg, isMe),
                );
              },
            ),
          ),
          // Reply preview
          if (_replyTo != null) _buildReplyPreviewOverlay(),
          // Edit mode indicator
          if (_editingMsg != null) _buildEditPreviewOverlay(),
          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildReplyPreviewOverlay() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(width: 4, height: 40, color: AppTheme.primaryGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _replyTo!.senderName ?? 'Kamu',
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _replyTo!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildEditPreviewOverlay() {
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mengedit pesan',
                    style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text(
                  _editingMsg!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _cancelEdit,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    if (_isRecording) return _buildRecordingBar();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.emoji_emotions_outlined,
                color: Colors.grey,
              ),
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                decoration: InputDecoration(
                  hintText: 'Pesan',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (v) {
                  context.read<SocketProvider>().sendTyping(
                        conv.id,
                        v.isNotEmpty,
                      );
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.attach_file, color: Colors.grey),
              onPressed: _sendImage,
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _textCtrl,
              builder: (ctx, val, __) {
                final hasText = val.text.trim().isNotEmpty;
                if (hasText) {
                  return GestureDetector(
                    onTap: _editingMsg != null ? _submitEdit : _sendText,
                    child: _buildCircleButton(
                      icon: _editingMsg != null ? Icons.check : Icons.send,
                      color: _editingMsg != null
                          ? Colors.blue
                          : AppTheme.primaryGreen,
                    ),
                  );
                }

                // Voice Record Button (Hold to Record)
                return GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecording(),
                  onLongPressMoveUpdate: (details) =>
                      _updateRecordingStatus(details.localPosition),
                  child: _buildCircleButton(
                    icon: Icons.mic,
                    color: _isCancelling ? Colors.red : AppTheme.primaryGreen,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(Icons.mic, color: Colors.red, size: 20),
            const SizedBox(width: 12),
            Text(
              '${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              _isCancelling
                  ? 'Lepaskan untuk batal'
                  : 'Geser ke kiri untuk batal',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_back_ios, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required Color color}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

// ─── MessageBubble ────────────────────────────────────────────────────────────
class MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final bool showSender;
  final VoidCallback onSwipe;
  final VoidCallback onLongPress;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.isMe,
    required this.showSender,
    required this.onSwipe,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (msg.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            msg.content,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      );
    }

    final bubbleColor = isMe ? AppTheme.senderBubble : AppTheme.receiverBubble;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
    );

    return Dismissible(
      key: ValueKey('msg_${msg.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onSwipe();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.reply, color: AppTheme.primaryGreen),
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSender)
                    Text(
                      msg.senderName ?? '',
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (msg.replyTo != null) _buildReplyPreview(),
                  if (msg.isImage && !msg.isDeleted)
                    _buildImageContent(context)
                  else if (msg.type == 'audio' && !msg.isDeleted)
                    AudioPlayerWidget(url: apiService.getMediaUrl(msg.content))
                  else
                    Text(
                      msg.content,
                      style: TextStyle(
                        fontSize: 15,
                        color: msg.isDeleted ? Colors.grey : null,
                        fontStyle:
                            msg.isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (msg.isEdited && !msg.isDeleted)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text('diedit',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic)),
                        ),
                      Text(
                        DateFormat('HH:mm').format(msg.createdAt),
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.status == 'read' || msg.status == 'delivered'
                              ? Icons.done_all
                              : Icons.done,
                          size: 14,
                          color:
                              msg.status == 'read' ? Colors.blue : Colors.grey,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: AppTheme.primaryGreen, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg.replySenderName ?? '',
            style: const TextStyle(
              color: AppTheme.primaryGreen,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            msg.replyContent ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final url = apiService.getMediaUrl(msg.content);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.black),
            body: Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          // Use natural image size, capped at screen width * 0.65
          width: MediaQuery.of(context).size.width * 0.65,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, size: 60),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: MediaQuery.of(context).size.width * 0.65,
              height: 180,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }
}

// ─── AudioPlayerWidget ────────────────────────────────────────────────────────
class AudioPlayerWidget extends StatefulWidget {
  final String url;
  const AudioPlayerWidget({super.key, required this.url});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.setReleaseMode(ReleaseMode.stop);

    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    await _player.play(UrlSource(widget.url));
  }

  Future<void> _pause() async {
    await _player.pause();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final totalSecs = _duration.inSeconds;
    final currSecs = _position.inSeconds;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: isPlaying ? _pause : _play,
            child: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: AppTheme.primaryGreen,
              size: 40,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    value: currSecs.toDouble(),
                    max: totalSecs > 0 ? totalSecs.toDouble() : 1.0,
                    activeColor: AppTheme.primaryGreen,
                    inactiveColor: Colors.black12,
                    onChanged: (v) {
                      _player.seek(Duration(seconds: v.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${currSecs ~/ 60}:${(currSecs % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black54),
                      ),
                      Text(
                        '${totalSecs ~/ 60}:${(totalSecs % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Extension to expose toMap
extension MessageModelX on MessageModel {
  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'type': type,
        'content': content,
        'reply_to': replyTo,
        'sender_name': senderName,
        'sender_avatar': senderAvatar,
        'created_at': createdAt.toIso8601String(),
        'status': status,
      };
}
