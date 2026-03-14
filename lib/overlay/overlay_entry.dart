// lib/overlay/overlay_entry.dart
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
  String subtitle = ""; // Start empty so it hides correctly

  // Fallback default preference
  UserPreference _currentPrefs = UserPreference(
    sourceLanguageCode: 'en',
    targetLanguageCode: 'en',
    fontSizeScale: 18.0,
    overlayOpacity: 80,
    textColorHex: '#FFFFFF',
    bgColorHex: '#000000',
    isTutorialCompleted: true,
  );

  @override
  void initState() {
    super.initState();

    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data == null) return;

      if (data is Map) {
        // Only parse Maps if they contain our specific settings key
        if (data.containsKey('target_language_code')) {
          setState(() {
            _currentPrefs = UserPreference.fromMap(Map<String, dynamic>.from(data));
          });
        }
        // IGNORE all other maps (like {"action": "close"}, {"status": "ready"})
      }
      // STRICTLY check for strings to update the subtitle
      else if (data is String) {
        setState(() => subtitle = data);
      }
    });

    // Ping the main app that we are alive
    FlutterOverlayWindow.shareData({"status": "ready"});
  }

  @override
  Widget build(BuildContext context) {
    // Removed the redundant Material wrapper since floating_bubble uses Scaffold
    return FloatingBubble(
      text: subtitle,
      prefs: _currentPrefs,
    );
  }
}