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

class _OverlayAppState extends State<OverlayApp> with WidgetsBindingObserver {
  String subtitle = "";
  UserPreference? _currentPrefs;

  bool _isRunning = false;
  bool _isPaused = false;

  int _bootCount = 0; //

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferencesDirectly();

    FlutterOverlayWindow.overlayListener.listen((data) {
      if (!mounted || data == null) return;

      if (data is Map) {
        final type = data['type'];

        if (type == 'wake_up') {
          setState(() {
            subtitle = "";
            _bootCount++;
          });
          _sendReadyPing();
        }
        else if (type == 'status_update') {
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
      _sendReadyPing();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sendReadyPing();
    }
  }

  void _sendReadyPing() {
    final SendPort? sendPort = ui.IsolateNameServer.lookupPortByName('vox_overlay_port');
    sendPort?.send("ACTION_PREFIX:overlay_ready");
    FlutterOverlayWindow.shareData({"status": "ready"});
  }

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
      // 🟢 THE FIX: The "Visible" Waiting Room.
      // We mimic the exact look of the closed FloatingBubble so Android
      // allocates a real GraphicBuffer on Frame 1, preventing the 4x4 crash.
      return Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.01),
        body: SizedBox(
          width: 100, // Matches _kCollapsedSize in floating_bubble
          height: 100,
          child: Center(
            child: Container(
              width: 60, // Matches _kBubbleRadius * 2
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: Center(
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 28,
                  height: 28,
                  errorBuilder: (_, __, ___) => const Icon(Icons.mic, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return FloatingBubble(
      key: ValueKey(_bootCount),
      text: subtitle,
      prefs: _currentPrefs!,
      isRunning: _isRunning,
      isPaused: _isPaused,
    );
  }
}