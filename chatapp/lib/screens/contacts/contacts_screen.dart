import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/socket_provider.dart';
import '../../utils/app_theme.dart';
import '../profile/profile_screen.dart' show formatLastSeen;
import '../chat/chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // ── Add-by-phone state ────────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  UserModel? _foundUser;
  bool _searching = false;
  String? _searchError;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Normalise phone: 08xx → +628xx, already +62 → keep ───────────
  String _normalise(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('62')) return '+$digits';
    if (digits.startsWith('0')) return '+62${digits.substring(1)}';
    return '+62$digits';
  }

  Future<void> _searchByPhone() async {
    final cp = context.read<ContactProvider>();
    final raw = _phoneCtrl.text.trim();
    if (raw.isEmpty) return;

    setState(() {
      _searching = true;
      _foundUser = null;
      _searchError = null;
    });

    final normalised = _normalise(raw);
    await cp.searchUsers(normalised);

    if (!mounted) return;
    final results = cp.searchResults;

    if (results.isEmpty) {
      setState(() {
        _searchError = 'Nomor "$normalised" tidak terdaftar di ChatApp';
        _searching = false;
      });
    } else {
      setState(() {
        _foundUser = results.first;
        _searching = false;
      });
    }
  }

  Future<void> _addAndChat(UserModel user) async {
    // Capture all context-dependent objects BEFORE any await
    final cp = context.read<ContactProvider>();
    final chat = context.read<ChatProvider>();
    final socket = context.read<SocketProvider>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Add to contacts (ignore if already added)
    await cp.addContact(user.id);

    // Open DM
    final convId = await chat.createOrGetDM(user.id);
    if (!mounted) return;
    if (convId != null) {
      socket.joinRoom(convId);
      final conv = chat.conversations.firstWhere(
        (c) => c.id == convId,
        orElse: () => chat.conversations.first,
      );
      nav.pop(); // close sheet
      nav.push(
          MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)));
    } else {
      messenger
          .showSnackBar(const SnackBar(content: Text('Gagal membuka chat')));
    }
  }

  // ── Bottom sheet ──────────────────────────────────────────────────
  void _showAddContactSheet() {
    _phoneCtrl.clear();
    setState(() {
      _foundUser = null;
      _searchError = null;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_add_alt_1,
                          color: AppTheme.primaryGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('Tambah Kontak',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Masukkan nomor HP yang terdaftar di ChatApp',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 20),

                // Phone input
                Row(
                  children: [
                    // Country code badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Text('+62',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        autofocus: true,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: '8xx xxxx xxxx',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _phoneCtrl.clear();
                              setSheet(() {});
                              setState(() {
                                _foundUser = null;
                                _searchError = null;
                              });
                            },
                          ),
                        ),
                        onSubmitted: (_) async {
                          await _searchByPhone();
                          setSheet(() {});
                        },
                        onChanged: (_) => setSheet(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _phoneCtrl.text.trim().isEmpty
                        ? null
                        : () async {
                            await _searchByPhone();
                            setSheet(() {});
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search),
                    label: Text(_searching ? 'Mencari...' : 'Cari'),
                  ),
                ),
                const SizedBox(height: 16),

                // Error
                if (_searchError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_searchError!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                // Found user card
                if (_foundUser != null) _buildFoundUserCard(_foundUser!, ctx),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFoundUserCard(UserModel user, BuildContext sheetCtx) {
    final cp = context.read<ContactProvider>();
    final alreadyAdded = cp.contacts.any((c) => c['user_id'] == user.id);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.08),
            Colors.teal.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar + info
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.primaryGreen,
                backgroundImage: (() {
                  final av = user.avatar;
                  return (av != null && av.isNotEmpty)
                      ? NetworkImage(av)
                      : null;
                })(),
                child: (() {
                  final av = user.avatar;
                  return (av == null || av.isEmpty)
                      ? Text(user.name[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold))
                      : null;
                })(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(user.phone,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13)),
                    if (user.statusMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          user.statusMessage,
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (user.isOnline)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: Colors.green, size: 8),
                            SizedBox(width: 4),
                            Text('Online',
                                style: TextStyle(
                                    color: Colors.green, fontSize: 11)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Action buttons
          Row(
            children: [
              if (!alreadyAdded)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final nav2 = Navigator.of(sheetCtx);
                      final msg2 = ScaffoldMessenger.of(sheetCtx);
                      await cp.addContact(user.id);
                      if (!mounted) return;
                      nav2.pop();
                      msg2.showSnackBar(
                        SnackBar(
                          content: Text('${user.name} ditambahkan ke kontak'),
                          backgroundColor: AppTheme.primaryGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add,
                        color: AppTheme.primaryGreen, size: 18),
                    label: const Text('Tambah',
                        style: TextStyle(color: AppTheme.primaryGreen)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryGreen),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              if (!alreadyAdded) const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addAndChat(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Chat'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ContactProvider>();

    return Scaffold(
      body: cp.loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : cp.contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.contacts_outlined,
                            size: 60,
                            color:
                                AppTheme.primaryGreen.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 20),
                      const Text('Belum ada kontak',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54)),
                      const SizedBox(height: 8),
                      Text('Tambah kontak lewat nomor HP mereka',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 13)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddContactSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Tambah Kontak'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => cp.loadContacts(),
                  color: AppTheme.primaryGreen,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: cp.contacts.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 0, indent: 72),
                    itemBuilder: (_, i) {
                      final c = cp.contacts[i];
                      final name = c['nickname'] ?? c['name'];
                      final phone = c['phone'] ?? '';
                      final avatar = c['avatar'];
                      final userId = c['user_id'];
                      final isOnline =
                          c['is_online'] == 1 || c['is_online'] == true;
                      final lastSeen = c['last_seen'] != null
                          ? DateTime.tryParse(c['last_seen'].toString())
                          : null;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppTheme.primaryGreen,
                              backgroundImage:
                                  avatar != null && avatar.toString().isNotEmpty
                                      ? NetworkImage(avatar.toString())
                                      : null,
                              child:
                                  (avatar == null || avatar.toString().isEmpty)
                                      ? Text(
                                          name.toString().isNotEmpty
                                              ? name.toString()[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        )
                                      : null,
                            ),
                            if (isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(name.toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          isOnline
                              ? 'Online'
                              : (lastSeen != null
                                  ? 'Terakhir ${formatLastSeen(lastSeen)}'
                                  : phone.toString()),
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  isOnline ? Colors.green : Colors.grey[500]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Chat button
                            _ActionBtn(
                              icon: Icons.chat_bubble_outline,
                              color: AppTheme.primaryGreen,
                              onTap: () async {
                                final chat = context.read<ChatProvider>();
                                final socket = context.read<SocketProvider>();
                                final nav = Navigator.of(context);
                                final convId =
                                    await chat.createOrGetDM(userId.toString());
                                if (convId != null && mounted) {
                                  socket.joinRoom(convId);
                                  final conv = chat.conversations.firstWhere(
                                    (c) => c.id == convId,
                                    orElse: () => chat.conversations.first,
                                  );
                                  nav.push(MaterialPageRoute(
                                      builder: (_) =>
                                          ChatScreen(conversation: conv)));
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            // Delete button
                            _ActionBtn(
                              icon: Icons.delete_outline,
                              color: Colors.red,
                              onTap: () => _confirmDelete(
                                  context, c['id'].toString(), cp),
                            ),
                          ],
                        ),
                        onTap: () async {
                          final chat = context.read<ChatProvider>();
                          final socket = context.read<SocketProvider>();
                          final nav = Navigator.of(context);
                          final convId =
                              await chat.createOrGetDM(userId.toString());
                          if (convId != null && mounted) {
                            socket.joinRoom(convId);
                            final conv = chat.conversations.firstWhere(
                              (c) => c.id == convId,
                              orElse: () => chat.conversations.first,
                            );
                            nav.push(MaterialPageRoute(
                                builder: (_) =>
                                    ChatScreen(conversation: conv)));
                          }
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: cp.contacts.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showAddContactSheet,
              backgroundColor: AppTheme.primaryGreen,
              child: const Icon(Icons.person_add, color: Colors.white),
            )
          : null,
    );
  }

  void _confirmDelete(BuildContext context, String id, ContactProvider cp) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Kontak'),
        content: const Text('Yakin ingin menghapus kontak ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              cp.deleteContact(id);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

// ── Small icon action button ──────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
