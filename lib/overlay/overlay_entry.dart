import 'dart:convert';
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
      if (data == null) return;

      if (data is Map) {
        final type = data['type'];
        
        if (type == 'status_update') {
          // Sync pipeline status from main app
          setState(() {
            _isRunning = data['isRunning'] ?? false;
            _isPaused = data['isPaused'] ?? false;
          });
        } else if (data.containsKey('target_language_code')) {
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

    FlutterOverlayWindow.shareData({"status": "ready"});
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPrefs == null) {
      return const SizedBox.shrink();
    }

    return FloatingBubble(
      text: subtitle,
      prefs: _currentPrefs!,
      isRunning: _isRunning,
      isPaused: _isPaused,
    );
  }
}
