// overlay_entry.dart
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'floating_bubble.dart';
import '../models/user_preference.dart';
import '../db/database_helper.dart';

class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});
  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  String subtitle = "";
  UserPreference? _currentPrefs;

  bool _isRunning = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();

    // 2. ADDED: Fetch preferences directly from the DB on boot.
    _loadPreferencesDirectly();

    FlutterOverlayWindow.overlayListener.listen((data) {
      if (!mounted || data == null) return;

      if (data is Map) {
        final type = data['type'];

        if (type == 'status_update') {
          setState(() {
            _isRunning = data['isRunning'] ?? false;
            _isPaused = data['isPaused'] ?? false;
          });
        } else if (data.containsKey('target_language_code') || data.containsKey('fontSizeScale')) {
          setState(() {
            _currentPrefs = UserPreference.fromMap(Map<String, dynamic>.from(data));
          });
        }
      }
      else if (data is String) {
        if (!data.startsWith("ACTION_PREFIX:")) {
          setState(() => subtitle = data);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 3. FIXED: SendPort (from dart:isolate), IsolateNameServer (from dart:ui)
      final SendPort? sendPort = ui.IsolateNameServer.lookupPortByName('vox_overlay_port');
      sendPort?.send("ACTION_PREFIX:overlay_ready");

      // Keep the original as a fallback
      FlutterOverlayWindow.shareData({"status": "ready"});
    });
  }

  // Helper method to load prefs from SQLite
  Future<void> _loadPreferencesDirectly() async {
    try {
      final prefs = await DatabaseHelper.instance.getPreferences();
      if (mounted) {
        setState(() => _currentPrefs = prefs);
      }
    } catch (e) {
      debugPrint("Overlay failed to load prefs directly: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
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