// lib/overlay/overlay_entry.dart
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'floating_bubble.dart';
import '../models/user_preference.dart';

class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});
  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  String subtitle = "";

  // 1. Make it nullable so we don't accidentally render fake defaults.
  UserPreference? _currentPrefs;

  @override
  void initState() {
    super.initState();

    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data == null) return;

      // 2. Safely handle if data is a Map
      if (data is Map) {
        _handleMapData(data);
      }
      // 3. Handle Strings (Subtitles OR JSON Strings)
      else if (data is String) {
        try {
          // Sometimes platform channels send Maps as JSON strings.
          // Let's check if this string is actually our settings JSON.
          final decoded = jsonDecode(data);
          if (decoded is Map) {
            _handleMapData(decoded);
            return; // Exit early so we don't set the subtitle to a JSON blob
          }
        } catch (_) {
          // If jsonDecode fails, it's a regular subtitle string.
          setState(() => subtitle = data);
        }
      }
    });

    // 4. Ping the main app that we are ready to receive data
    FlutterOverlayWindow.shareData({"status": "ready"});
  }

  void _handleMapData(Map dynamicData) {
    if (dynamicData.containsKey('target_language_code')) {
      setState(() {
        _currentPrefs = UserPreference.fromMap(Map<String, dynamic>.from(dynamicData));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 5. Do not render the bubble at all until real preferences arrive
    if (_currentPrefs == null) {
      return const SizedBox.shrink();
    }

    return FloatingBubble(
      text: subtitle,
      prefs: _currentPrefs!, // Safe to use '!' here
    );
  }
}