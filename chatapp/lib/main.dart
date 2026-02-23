import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/socket_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_screen.dart';
import 'utils/app_theme.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Background Handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SocketProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
      ],
      child: ChatApp(isLoggedIn: token != null && token.isNotEmpty),
    ),
  );
}

class ChatApp extends StatelessWidget {
  final bool isLoggedIn;
  const ChatApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final navigatorKey = GlobalKey<NavigatorState>();
    // Give SocketProvider access to navigator for incoming-call push
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sp = context.read<SocketProvider>();
      sp.navigatorContext = navigatorKey.currentContext;
    });

    return MaterialApp(
      title: 'ChatApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      navigatorKey: navigatorKey,
      home: isLoggedIn ? const MainScreen() : const LoginScreen(),
      builder: (ctx, child) {
        // Setup listeners once
        _setupFCMListeners(ctx, navigatorKey);

        // Keep navigatorContext up to date after navigation changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final sp = ctx.read<SocketProvider>();
          sp.navigatorContext = navigatorKey.currentContext;
        });
        return child!;
      },
    );
  }

  void _setupFCMListeners(
      BuildContext context, GlobalKey<NavigatorState> navKey) {
    // This should only run once, but builder runs many times.
    // Usually better in a StatefulWidget, but we can guard it.

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Background notifications are handled by the system and shown as heads-up
      // because of the AndroidManifest metadata and High Priority payload.
      // Foreground notifications can be handled here if we want custom UI.
      // print("Got a message in foreground: ${message.notification?.body}");
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Handle when user taps notification and app was in background
      // navigate to specific chat if needed
      // final convId = message.data['conversation_id'];
    });
  }
}
