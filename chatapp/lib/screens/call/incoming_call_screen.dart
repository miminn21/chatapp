import 'package:flutter/material.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerAvatar; // data URI or empty
  final String channelName; // conversation_id
  final bool isVideo;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerAvatar,
    required this.channelName,
    required this.isVideo,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final Animation<double> _ring1;
  late final Animation<double> _ring2;
  late final Animation<double> _ring3;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _ring1 = Tween<double>(begin: 0.8, end: 1.6).animate(CurvedAnimation(
        parent: _ringCtrl,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut)));
    _ring2 = Tween<double>(begin: 0.8, end: 1.6).animate(CurvedAnimation(
        parent: _ringCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));
    _ring3 = Tween<double>(begin: 0.8, end: 1.4).animate(CurvedAnimation(
        parent: _ringCtrl,
        curve: const Interval(0.4, 1.2, curve: Curves.easeOut)));
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            // Call type label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.isVideo
                    ? '📹 Panggilan Video Masuk'
                    : '📞 Panggilan Suara Masuk',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const SizedBox(height: 48),

            // Avatar with ripple animation
            AnimatedBuilder(
              animation: _ringCtrl,
              builder: (_, child) {
                return SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ripple rings
                      _Ring(
                          scale: _ring3.value,
                          opacity:
                              (1 - (_ring3.value - 0.8) / 0.6).clamp(0, 0.25)),
                      _Ring(
                          scale: _ring2.value,
                          opacity:
                              (1 - (_ring2.value - 0.8) / 0.8).clamp(0, 0.2)),
                      _Ring(
                          scale: _ring1.value,
                          opacity:
                              (1 - (_ring1.value - 0.8) / 0.8).clamp(0, 0.15)),
                      child!,
                    ],
                  ),
                );
              },
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF25D366),
                  border: Border.all(color: Colors.white24, width: 3),
                  image: widget.callerAvatar.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(widget.callerAvatar),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: widget.callerAvatar.isEmpty
                    ? Center(
                        child: Text(
                          widget.callerName.isNotEmpty
                              ? widget.callerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 32),

            // Caller name
            Text(
              widget.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sedang menelepon...',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),

            const Spacer(),

            // Accept / Reject buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject
                  _CallButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: 'Tolak',
                    onTap: () {
                      widget.onReject();
                      Navigator.pop(context);
                    },
                  ),
                  // Accept
                  _CallButton(
                    icon: widget.isVideo ? Icons.videocam : Icons.call,
                    color: const Color(0xFF25D366),
                    label: 'Terima',
                    onTap: () {
                      widget.onAccept();
                      Navigator.pop(context);
                    },
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

class _Ring extends StatelessWidget {
  final double scale;
  final double opacity;
  const _Ring({required this.scale, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF25D366).withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
