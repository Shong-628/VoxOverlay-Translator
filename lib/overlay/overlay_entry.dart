// overlay_entry.dart
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'floating_bubble.dart';
import '../models/user_preference.dart';

void runOverlayApp() {
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
  String subtitle = "Listening...";

  // 1. Provide a fallback default preference so the UI can render immediately
  UserPreference _currentPrefs = UserPreference(
    sourceLanguageCode: 'auto',
    targetLanguageCode: 'none',
    fontSizeScale: 1.0,
    overlayOpacity: 80,
    textColorHex: '#FFFFFF',
    bgColorHex: '#000000',
    isTutorialCompleted: true,
  );

  @override
  void initState() {
    super.initState();

    // Listen for data from the main app isolate
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data == null) return;

      // 2. Handle dynamically pushed preferences vs standard subtitle text
      if (data is Map && data.containsKey('target_language_code')) {
        // If the main app sends a Map matching the preference model, update the theme
        setState(() {
          _currentPrefs = UserPreference.fromMap(Map<String, dynamic>.from(data));
        });
      }
      else if (data is Map && data.containsKey('text')) {
        // Fallback for maps containing text
        setState(() => subtitle = data['text'].toString());
      }
      else {
        // Standard string data for subtitles
        setState(() => subtitle = data.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      // Note: We removed the Center() widget here because our new FloatingBubble
      // is designed to take over the full screen and manage its own coordinates.
      child: FloatingBubble(
        text: subtitle,
        prefs: _currentPrefs, // Pass the preferences down to the bubble
      ),
    );
  }
}