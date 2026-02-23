import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/conversation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';

class GroupInfoScreen extends StatefulWidget {
  final ConversationModel conversation;
  const GroupInfoScreen({super.key, required this.conversation});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  ConversationModel get conv => widget.conversation;
  bool _isLeaving = false;
  bool _isDeleting = false;

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar Grup'),
        content: Text('Yakin ingin keluar dari "${conv.displayName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isLeaving = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final me = context.read<AuthProvider>().user!;
    final chat = context.read<ChatProvider>();
    try {
      // Find group id from conversation members endpoint
      final convDetail = await apiService.get('/conversations/${conv.id}');
      final groupId = convDetail.data['data']['group']?['id'] ?? '';
      if (groupId.isNotEmpty) {
        final resp =
            await apiService.delete('/groups/$groupId/members/${me.id}');
        if (resp.data['success'] == true) {
          await chat.loadConversations();
          nav.popUntil((r) => r.isFirst);
          return;
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal keluar grup: $e')),
      );
    }
    setState(() => _isLeaving = false);
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Grup'),
        content: Text(
            '"${conv.displayName}" akan DIHAPUS permanen beserta semua pesan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final chat = context.read<ChatProvider>();
    try {
      final resp = await apiService.delete('/groups/${conv.id}');
      if (resp.data['success'] == true) {
        await chat.loadConversations();
        nav.popUntil((r) => r.isFirst);
        messenger.showSnackBar(const SnackBar(content: Text('Grup dihapus')));
        return;
      }
      messenger.showSnackBar(
          SnackBar(content: Text(resp.data['message'] ?? 'Gagal hapus grup')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal hapus grup: $e')));
    }
    setState(() => _isDeleting = false);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user!;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.primaryGreen,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  conv.displayAvatar != null && conv.displayAvatar!.isNotEmpty
                      ? Image.network(conv.displayAvatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: AppTheme.primaryGreen))
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF128C7E), Color(0xFF075E54)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                  Container(color: Colors.black26),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 41,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: conv.displayAvatar != null &&
                                    conv.displayAvatar!.isNotEmpty
                                ? NetworkImage(conv.displayAvatar!)
                                : null,
                            child: conv.displayAvatar == null ||
                                    conv.displayAvatar!.isEmpty
                                ? const Icon(Icons.group,
                                    size: 40, color: Colors.white)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          conv.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black38)
                            ],
                          ),
                        ),
                        if (conv.groupDescription != null &&
                            conv.groupDescription!.isNotEmpty)
                          Text(
                            conv.groupDescription!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),

              // Member count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${conv.members.length} anggota',
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Members list
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: List.generate(conv.members.length, (i) {
                    final member = conv.members[i];
                    final isSelf = member.id == me.id;
                    return Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryGreen,
                            backgroundImage: member.avatarUrl != null
                                ? NetworkImage(member.avatarUrl!)
                                : null,
                            child: member.avatarUrl == null
                                ? Text(
                                    member.name.isNotEmpty
                                        ? member.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          title: Text(
                            isSelf ? '${member.name} (Kamu)' : member.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(member.phone,
                              style: const TextStyle(fontSize: 12)),
                          trailing: member.isOnline
                              ? const CircleAvatar(
                                  radius: 5,
                                  backgroundColor: Colors.green,
                                )
                              : null,
                        ),
                        if (i < conv.members.length - 1)
                          const Divider(height: 0, indent: 72),
                      ],
                    );
                  }),
                ),
              ),

              const SizedBox(height: 16),

              // Leave group
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text('Keluar Grup',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600)),
                  onTap: _isLeaving ? null : _leaveGroup,
                  trailing: _isLeaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                ),
              ),

              const SizedBox(height: 8),

              // Delete group (admin only)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Hapus Grup',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Hanya untuk admin',
                      style: TextStyle(fontSize: 11)),
                  onTap: _isDeleting ? null : _deleteGroup,
                  trailing: _isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                ),
              ),

              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }
}
