import 'dart:convert';
import 'package:flutter/material.dart';

/// Universal image widget that handles:
/// - data:image/...;base64,<data>  (BLOB stored in DB, returned by API)
/// - http(s):// URLs               (legacy or message images served from disk)
/// - null / empty                  (shows initials fallback)
class AvatarImage extends StatelessWidget {
  final String? src;
  final double radius;
  final String? fallbackText;
  final Color backgroundColor;
  final BoxFit fit;

  const AvatarImage({
    super.key,
    required this.src,
    this.radius = 24,
    this.fallbackText,
    this.backgroundColor = const Color(0xFF128C7E),
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (src == null || src!.isEmpty) {
      return _fallback();
    }

    if (src!.startsWith('data:')) {
      // Base64 data URI
      try {
        final commaIndex = src!.indexOf(',');
        final base64Data = src!.substring(commaIndex + 1);
        final bytes = base64Decode(base64Data);
        return CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        return _fallback();
      }
    }

    // Regular network URL
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: NetworkImage(src!),
      onBackgroundImageError: (_, __) {},
      child: null,
    );
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        fallbackText?.isNotEmpty == true ? fallbackText![0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

/// Displays a full-screen image from a data URI or http URL
class FullImageViewer extends StatelessWidget {
  final String? src;

  const FullImageViewer({super.key, this.src});

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (src == null || src!.isEmpty) {
      img = const Center(
        child: Icon(Icons.broken_image, size: 80, color: Colors.white54),
      );
    } else if (src!.startsWith('data:')) {
      try {
        final commaIndex = src!.indexOf(',');
        final bytes = base64Decode(src!.substring(commaIndex + 1));
        img = InteractiveViewer(
          child: Image.memory(bytes, fit: BoxFit.contain),
        );
      } catch (_) {
        img = const Center(
          child: Icon(Icons.broken_image, size: 80, color: Colors.white54),
        );
      }
    } else {
      img = InteractiveViewer(
        child: Image.network(src!, fit: BoxFit.contain),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
      body: Center(child: img),
    );
  }
}
