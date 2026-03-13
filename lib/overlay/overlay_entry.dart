// overlay_entry.dart
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'floating_bubble.dart';
import '../models/user_preference.dart';

@pragma("vm:entry-point")
void overlayMain() { // 2. RENAMED TO overlayMain
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayApp(),
  ));
}

class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});
  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  String subtitle = "...";

  // Fallback default preference so the UI can render immediately
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

    // Listen for live updates (e.g., if user changes settings while overlay is open)
    FlutterOverlayWindow.overlayListener.listen((data) {
      dev.log("OVERLAY RECEIVED DATA: $data");
      if (data == null) return;

      if (data is Map && data.containsKey('target_language_code')) {
        setState(() {
          _currentPrefs = UserPreference.fromMap(Map<String, dynamic>.from(data));
        });
      }
      else if (data is Map && data.containsKey('text')) {
        setState(() => subtitle = data['text'].toString());
      }
      else {
        setState(() => subtitle = data.toString());
      }
    });
    FlutterOverlayWindow.shareData({"status": "ready"});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: FloatingBubble(
        text: subtitle,
        prefs: _currentPrefs,
      ),
    );
  }
}