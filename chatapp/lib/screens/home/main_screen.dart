import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/contact_provider.dart';
import '../../providers/socket_provider.dart';
import '../../utils/app_theme.dart';
import 'chats_tab.dart';
import '../contacts/contacts_screen.dart';
import '../profile/profile_screen.dart';
import '../auth/login_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  void _init() {
    final auth = context.read<AuthProvider>();
    final chat = context.read<ChatProvider>();
    final contacts = context.read<ContactProvider>();
    final socket = context.read<SocketProvider>();

    chat.loadConversations();
    contacts.loadContacts();

    // Connect socket if not already connected (e.g. after auto-login via stored token)
    if (!socket.connected) {
      socket.connect();
    }

    final myId = auth.user?.id ?? '';

    // Hook socket events to providers
    socket.onNewMessage = (data) => chat.onNewMessage(data, myUserId: myId);
    socket.onTyping = (data) => chat.onTyping(data);
    socket.onMessageRead = (data) {
      final msgId = data['message_id'] as String? ?? '';
      if (msgId.isNotEmpty) chat.updateMessageStatus(msgId, 'read');
    };
    socket.onMessageStatusUpdate = (data) {
      final msgId = data['message_id'] as String? ?? '';
      final status = data['status'] as String? ?? 'sent';
      if (msgId.isNotEmpty) chat.updateMessageStatus(msgId, status);
    };
    socket.onUserOnline = (data) {
      final uid = data['userId'] as String? ?? '';
      chat.updateUserOnlineStatus(uid, true);
    };
    socket.onUserOffline = (data) {
      final uid = data['userId'] as String? ?? '';
      chat.updateUserOnlineStatus(uid, false);
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        title: const Row(
          children: [
            Icon(Icons.chat_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'ChatApp',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => _showSearch(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) async {
              if (val == 'logout') {
                final nav = Navigator.of(context);
                final auth = context.read<AuthProvider>();
                final socket = context.read<SocketProvider>();
                await auth.logout();
                socket.disconnect();
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Text('Keluar')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'CHAT'),
            Tab(text: 'KONTAK'),
            Tab(text: 'PROFIL'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [ChatsTab(), ContactsScreen(), ProfileScreen()],
      ),
      floatingActionButton:
          _tabController.index == 0 ? const ChatsTabFab() : null,
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _ChatSearchDelegate(context.read<ContactProvider>()),
    );
  }
}

class _ChatSearchDelegate extends SearchDelegate<String> {
  final ContactProvider contactProvider;
  _ChatSearchDelegate(this.contactProvider);

  @override
  String get searchFieldLabel => 'Cari pengguna...';

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            contactProvider.clearSearch();
          },
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) => _buildSearchBody(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    contactProvider.searchUsers(query);
    return _buildSearchBody(context);
  }

  Widget _buildSearchBody(BuildContext context) {
    return Consumer<ContactProvider>(
      builder: (ctx, cp, _) {
        if (cp.searchResults.isEmpty) {
          return const Center(child: Text('Tidak ada hasil'));
        }
        return ListView.builder(
          itemCount: cp.searchResults.length,
          itemBuilder: (_, i) {
            final u = cp.searchResults[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryGreen,
                backgroundImage:
                    u.avatar != null ? NetworkImage(u.avatar!) : null,
                child: u.avatar == null
                    ? Text(
                        u.name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              ),
              title: Text(u.name),
              subtitle: Text(u.phone),
              onTap: () => close(context, u.id),
            );
          },
        );
      },
    );
  }
}
