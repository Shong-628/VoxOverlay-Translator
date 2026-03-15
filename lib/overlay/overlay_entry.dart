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

  @override
  void initState() {
    super.initState();

    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data == null) return;

      if (data is Map) {
        _handleMapData(data);
      }
      else if (data is String) {
        // PERF FIX: Only try to decode if the string actually looks like a JSON Map.
        // This prevents throwing/catching FormatExceptions on every single plain-text subtitle.
        if (data.trimLeft().startsWith('{')) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map) {
              _handleMapData(decoded);
              return;
            }
          } catch (_) {
            // If it looked like JSON but failed to parse, fall back to subtitle
          }
        }

        // If it's a regular string, update the subtitle
        setState(() => subtitle = data);
      }
    });

    // Ping the main app that we are attached and ready to receive preferences
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
    if (_currentPrefs == null) {
      return const SizedBox.shrink();
    }

    return FloatingBubble(
      text: subtitle,
      prefs: _currentPrefs!,
    );
  }
}