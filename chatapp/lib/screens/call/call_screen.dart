import 'package:agora_uikit/agora_uikit.dart';
import 'package:flutter/material.dart';

const String _agoraAppId = '47001365e4694c4cbf3a504571ec3254';

class CallScreen extends StatefulWidget {
  final String channelName; // conversation_id
  final String callerName;
  final bool isVideo;
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.channelName,
    required this.callerName,
    required this.isVideo,
    this.isCaller = true,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final AgoraClient _client;
  bool _joined = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    _client = AgoraClient(
      agoraConnectionData: AgoraConnectionData(
        appId: _agoraAppId,
        channelName: widget.channelName,
        // token not required in testing mode (Agora App without token auth)
      ),
      enabledPermission: [
        Permission.camera,
        Permission.microphone,
      ],
    );
    try {
      await _client.initialize();
      if (mounted) setState(() => _joined = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _client.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text('Gagal terhubung:\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_joined) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 20),
              Text(
                widget.isVideo
                    ? 'Menghubungkan video call...'
                    : 'Menghubungkan panggilan...',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video/Voice view
            if (widget.isVideo)
              AgoraVideoViewer(
                client: _client,
                layoutType: Layout.floating,
                disabledVideoWidget: _NoVideoWidget(name: widget.callerName),
              )
            else
              _VoiceCallBackground(name: widget.callerName),

            // Controls
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: AgoraVideoButtons(
                  client: _client,
                  disconnectButtonChild: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end,
                        color: Colors.white, size: 28),
                  ),
                  onDisconnect: () => Navigator.pop(context),
                ),
              ),
            ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.callerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.isVideo ? '📹 Video Call' : '📞 Suara',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Voice call background ──────────────────────────────────────────────────────
class _VoiceCallBackground extends StatelessWidget {
  final String name;
  const _VoiceCallBackground({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A237E), Color(0xFF0D1B2A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(color: Colors.white30, width: 2),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Sedang dalam panggilan...',
                style: TextStyle(color: Colors.white60, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ── No camera widget ───────────────────────────────────────────────────────────
class _NoVideoWidget extends StatelessWidget {
  final String name;
  const _NoVideoWidget({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A237E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(name,
                style: const TextStyle(color: Colors.white70, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
