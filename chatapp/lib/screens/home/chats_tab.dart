import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/socket_provider.dart';
import '../../models/conversation_model.dart';
import '../../utils/app_theme.dart';
import '../chat/chat_screen.dart';
import '../chat/create_group_screen.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final me = context.watch<AuthProvider>().user;

    if (chat.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chat.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Belum ada percakapan',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tambah kontak dan mulai chat!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => chat.loadConversations(),
      child: ListView.builder(
        itemCount: chat.conversations.length,
        itemBuilder: (_, i) {
          final conv = chat.conversations[i];
          return ConversationTile(conv: conv, myId: me?.id ?? '');
        },
      ),
    );
  }
}

// FAB to create group — used by MainScreen
class ChatsTabFab extends StatelessWidget {
  const ChatsTabFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'fab_chat',
      onPressed: () async {
        final convId = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
        );
        if (convId != null && context.mounted) {
          final chat = context.read<ChatProvider>();
          final socket = context.read<SocketProvider>();
          socket.joinRoom(convId); // join socket room immediately
          final conv = chat.conversations.firstWhere(
            (c) => c.id == convId,
            orElse: () => chat.conversations.first,
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)),
          );
        }
      },
      tooltip: 'Buat Grup',
      child: const Icon(Icons.group_add),
    );
  }
}

class ConversationTile extends StatelessWidget {
  final ConversationModel conv;
  final String myId;

  const ConversationTile({super.key, required this.conv, required this.myId});

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return DateFormat('HH:mm').format(dt);
    }
    if (now.difference(dt).inDays < 7) {
      return DateFormat('EEE', 'id').format(dt);
    }
    return DateFormat('dd/MM/yy').format(dt);
  }

  String _lastMessagePreview() {
    if (conv.lastMessage == null) return 'Mulai percakapan...';
    final type = conv.lastMessageType ?? 'text';
    if (type == 'image') return '📷 Foto';
    if (type == 'video') return '🎥 Video';
    if (type == 'audio') return '🎤 Pesan suara';
    if (type == 'file') return '📎 Berkas';
    if (type == 'system') return conv.lastMessage!;
    return conv.lastMessage!;
  }

  @override
  Widget build(BuildContext context) {
    final avatar = conv.displayAvatar;
    final name = conv.displayName;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryGreen,
                  backgroundImage: avatar != null && avatar.isNotEmpty
                      ? NetworkImage(avatar)
                      : null,
                  child: (avatar == null || avatar.isEmpty)
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                if (conv.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Name + Preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (conv.isGroup) ...[
                        const Icon(Icons.group, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(conv.lastMessageAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: conv.unreadCount > 0
                              ? AppTheme.primaryGreen
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _lastMessagePreview(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conv.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${conv.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
