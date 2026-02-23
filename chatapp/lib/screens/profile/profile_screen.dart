import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/socket_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/avatar_image.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        _nameCtrl.text = user.name;
        _statusCtrl.text = user.statusMessage;
        _emailCtrl.text = user.email ?? '';
        _bioCtrl.text = user.bio ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _statusCtrl.dispose();
    _emailCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  // ─── Photo Picker ──────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    final picked = await _showImagePickerSheet();
    if (picked == null || !mounted) return;
    try {
      final auth = context.read<AuthProvider>();
      final form = FormData.fromMap({
        'avatar':
            await MultipartFile.fromFile(picked.path, filename: picked.name),
      });
      final resp = await apiService.putForm('/users/me/avatar', form);
      if (resp.data['success'] == true && mounted) {
        auth.updateAvatarLocal(resp.data['data']['avatar'] as String);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil diperbarui')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  Future<void> _pickCover() async {
    final picked = await _showImagePickerSheet(title: 'Foto Sampul');
    if (picked == null || !mounted) return;
    try {
      final auth = context.read<AuthProvider>();
      final form = FormData.fromMap({
        'cover':
            await MultipartFile.fromFile(picked.path, filename: picked.name),
      });
      final resp = await apiService.putForm('/users/me/cover', form);
      if (resp.data['success'] == true && mounted) {
        auth.updateCoverLocal(resp.data['data']['cover_photo'] as String);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto sampul diperbarui')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  /// WhatsApp-style bottom sheet: Camera | Galeri | (optionally remove)
  Future<XFile?> _showImagePickerSheet({String title = 'Foto Profil'}) async {
    final picker = ImagePicker();
    XFile? file;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 0),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF128C7E),
                child: Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: const Text('Kamera'),
              onTap: () async {
                Navigator.pop(ctx);
                file = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF075E54),
                child: Icon(Icons.photo_library, color: Colors.white),
              ),
              title: const Text('Galeri'),
              onTap: () async {
                Navigator.pop(ctx);
                file = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    return file;
  }

  // ─── Profile Save ──────────────────────────────────────────────
  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await auth.updateProfile(
      name: _nameCtrl.text.trim(),
      statusMessage: _statusCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
    );
    setState(() => _editing = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profil diperbarui!' : 'Gagal memperbarui'),
        backgroundColor: ok ? AppTheme.primaryGreen : Colors.red,
      ),
    );
  }

  // ─── View full-screen image ─────────────────────────────────────
  void _viewImage(String? src) {
    if (src == null || src.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullImageViewer(src: src),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar with cover + avatar ──────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppTheme.primaryGreen,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover photo
                  GestureDetector(
                    onTap: () => _viewImage(user.coverUrl),
                    child: _buildCoverWidget(user.coverUrl),
                  ),
                  // Dimmer
                  Container(color: Colors.black26),
                  // Edit cover button (top-right)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.add_photo_alternate,
                          color: Colors.white70),
                      tooltip: 'Ganti foto sampul',
                      onPressed: _pickCover,
                    ),
                  ),
                  // Avatar centred in bottom of FlexibleSpace
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => _viewImage(user.avatarUrl),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(3),
                                child: AvatarImage(
                                  src: user.avatarUrl,
                                  radius: 49,
                                  fallbackText: user.name,
                                  backgroundColor: Colors.grey,
                                ),
                              ),
                              // Camera badge
                              GestureDetector(
                                onTap: _pickAvatar,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF128C7E),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black38)
                            ],
                          ),
                        ),
                        Text(
                          user.phone,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(_editing ? Icons.close : Icons.edit,
                    color: Colors.white),
                onPressed: () => setState(() {
                  _editing = !_editing;
                  if (!_editing) {
                    _nameCtrl.text = user.name;
                    _statusCtrl.text = user.statusMessage;
                    _emailCtrl.text = user.email ?? '';
                  }
                }),
              ),
            ],
          ),

          // ── Body items ─────────────────────────────────────────
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),

              // Info / Edit card
              _card(
                children: _editing
                    ? [
                        _editField(Icons.person_outline, 'Nama', _nameCtrl),
                        const Divider(height: 0),
                        _editField(Icons.info_outline, 'Status', _statusCtrl),
                        const Divider(height: 0),
                        _editField(Icons.email_outlined, 'Email', _emailCtrl),
                        const Divider(height: 0),
                        _editField(Icons.menu_book_outlined, 'Bio', _bioCtrl,
                            maxLines: 4),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: ElevatedButton(
                            onPressed: _saveProfile,
                            child: const Text('Simpan'),
                          ),
                        ),
                      ]
                    : [
                        _infoRow(Icons.person_outline, 'Nama', user.name),
                        const Divider(height: 0),
                        _infoRow(
                            Icons.info_outline, 'Status', user.statusMessage),
                        if (user.bio != null && user.bio!.isNotEmpty) ...[
                          const Divider(height: 0),
                          _infoRow(Icons.menu_book_outlined, 'Bio', user.bio!),
                        ],
                        const Divider(height: 0),
                        _infoRow(Icons.phone_outlined, 'Telepon', user.phone),
                        if (user.email != null) ...[
                          const Divider(height: 0),
                          _infoRow(Icons.email_outlined, 'Email', user.email!),
                        ],
                      ],
              ),

              const SizedBox(height: 16),

              // Settings card
              _card(
                children: [
                  _settingTile(
                      Icons.notifications_outlined, 'Notifikasi', () {}),
                  const Divider(height: 0),
                  _settingTile(
                      Icons.lock_outlined, 'Privasi & Keamanan', () {}),
                  const Divider(height: 0),
                  _settingTile(Icons.help_outline, 'Bantuan', () {}),
                  const Divider(height: 0),
                  _settingTile(Icons.logout, 'Keluar', () async {
                    final nav = Navigator.of(context);
                    final authP = context.read<AuthProvider>();
                    final socket = context.read<SocketProvider>();
                    await authP.logout();
                    socket.disconnect();
                    nav.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }, color: Colors.red),
                ],
              ),

              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'ChatApp v1.0.0',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }

  // ─── Cover photo widget (handles data URI + http URL) ──────────
  Widget _buildCoverWidget(String? src) {
    if (src == null || src.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF128C7E), Color(0xFF075E54)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    }
    if (src.startsWith('data:')) {
      try {
        final bytes = base64Decode(src.substring(src.indexOf(',') + 1));
        return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity);
      } catch (_) {}
    }
    return Image.network(
      src,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: AppTheme.primaryGreen),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────
  Widget _card({required List<Widget> children}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: children),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryGreen, size: 22),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      );

  Widget _editField(IconData icon, String label, TextEditingController ctrl,
          {int? maxLines}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines ?? 1,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
            border: InputBorder.none,
          ),
        ),
      );

  Widget _settingTile(IconData icon, String title, VoidCallback onTap,
          {Color? color}) =>
      ListTile(
        leading: Icon(icon, color: color ?? Colors.grey[700]),
        title: Text(title,
            style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        trailing: color == null
            ? const Icon(Icons.chevron_right, color: Colors.grey)
            : null,
        onTap: onTap,
      );
}

// (FullImageViewer now provided by widgets/avatar_image.dart)

// ─── Last seen formatter ─────────────────────────────────────────────────────
String formatLastSeen(DateTime? lastSeen) {
  if (lastSeen == null) return 'terakhir dilihat beberapa waktu lalu';
  final now = DateTime.now();
  final diff = now.difference(lastSeen);
  if (diff.inMinutes < 1) return 'baru saja online';
  if (diff.inMinutes < 60) {
    return 'terakhir dilihat ${diff.inMinutes} menit lalu';
  }
  if (diff.inHours < 24) {
    return 'terakhir dilihat ${diff.inHours} jam lalu';
  }
  if (diff.inDays == 1) {
    return 'terakhir dilihat kemarin pukul ${DateFormat('HH:mm').format(lastSeen)}';
  }
  return 'terakhir dilihat ${DateFormat('dd/MM/yy').format(lastSeen)}';
}
