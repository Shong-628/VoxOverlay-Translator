// overlay_entry.dart
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
  UserPreference? _currentPrefs;

  // Track pipeline state in the overlay isolate
  bool _isRunning = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();

    FlutterOverlayWindow.overlayListener.listen((data) {
      if (!mounted || data == null) return;

      if (data is Map) {
        final type = data['type'];

        if (type == 'status_update') {
          // Sync pipeline status from main app
          setState(() {
            _isRunning = data['isRunning'] ?? false;
            _isPaused = data['isPaused'] ?? false;
          });
        } else if (data.containsKey('target_language_code') || data.containsKey('fontSizeScale')) {
          // Sync preferences
          setState(() {
            _currentPrefs = UserPreference.fromMap(Map<String, dynamic>.from(data));
          });
        }
      }
      else if (data is String) {
        // Only update subtitle if it's not a legacy command string
        if (!data.startsWith("ACTION_PREFIX:")) {
          setState(() => subtitle = data);
        }
      }
    });

    // FIX 1: Delay the "ready" ping until after the first frame renders.
    // This ensures the Android view is fully attached and listening before
    // we tell the main isolate to start sending data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterOverlayWindow.shareData({"status": "ready"});
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIX 2: Never allow the window to render at 0x0 (SizedBox.shrink).
    // Hold a transparent placeholder that exactly matches the 100x100 
    // _initialSize we defined in OverlayService until preferences arrive.
    if (_currentPrefs == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox(
          width: 100,
          height: 100,
        ),
      );
    }

    return FloatingBubble(
      text: subtitle,
      prefs: _currentPrefs!,
      isRunning: _isRunning,
      isPaused: _isPaused,
    );
  }
}