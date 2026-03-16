// overlay_service.dart
import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../db/database_helper.dart';
import '../models/user_preference.dart';

class OverlayService {
  static Completer<bool>? _overlayReadyCompleter;

  // Use the exact same size as _kCollapsedSize in floating_bubble.dart
  static const int _initialSize = 100;

  // UI Spam Protection (Throttle)
  static DateTime? _lastSubtitleUpdate;
  static const int _throttleMilliseconds = 300; // Limits updates to ~3 times per second

  static void handleSystemMessage(dynamic data) {
    if (data is Map && data['status'] == 'ready') {
      if (_overlayReadyCompleter != null && !_overlayReadyCompleter!.isCompleted) {
        _overlayReadyCompleter!.complete(true);
        dev.log("🟢 Overlay ping received: Ready!", name: 'OverlayService');
      }
    }
  }

  static Future<bool> hasPermission() async {
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  static Future<void> requestPermission() async {
    await FlutterOverlayWindow.requestPermission();
  }

  // ... (keep existing imports and top half of the file)

  static Future<void> startOverlay() async {
    try {
      bool permission = await hasPermission();
      if (!permission) {
        await requestPermission();
        if (!await hasPermission()) return;
      }

      bool isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        dev.log("Overlay thinks it's active. Forcing cleanup...", name: 'OverlayService');
        await FlutterOverlayWindow.closeOverlay();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      _overlayReadyCompleter = Completer<bool>();

      await FlutterOverlayWindow.showOverlay(
        height: _initialSize,
        width: _initialSize,
        alignment: OverlayAlignment.center,
        flag: OverlayFlag.defaultFlag,
        enableDrag: true,
      );

      // Send a WAKE UP ping. If the engine is a "Zombie",
      // initState() won't fire. This ping forces the overlay to acknowledge us.
      await FlutterOverlayWindow.shareData({'type': 'wake_up'});

      try {
        await _overlayReadyCompleter!.future.timeout(const Duration(seconds: 4));
      } catch (e) {
        dev.log("Timeout waiting for overlay ready ping. Proceeding anyway.", name: 'OverlayService');
      }

      final prefs = await DatabaseHelper.instance.getPreferences();
      await FlutterOverlayWindow.shareData(prefs.toMap());

    } catch (e) {
      dev.log("Error starting overlay", name: 'OverlayService', error: e);
    }
  }

  static Future<void> stopOverlay() async {
    try {
      if (!await FlutterOverlayWindow.isActive()) return;

      await FlutterOverlayWindow.closeOverlay();

      // FIX 3: Add a tiny delay to let the OS fully destroy the background surface.
      // This prevents "Zombie" isolates if the user immediately restarts the overlay.
      await Future.delayed(const Duration(milliseconds: 300));

      // Clear the completer so the next boot is totally fresh
      if (_overlayReadyCompleter != null && !_overlayReadyCompleter!.isCompleted) {
        _overlayReadyCompleter!.completeError("Overlay closed before ready");
      }
      _overlayReadyCompleter = null;

    } catch (e) {
      dev.log("Error closing overlay", name: 'OverlayService', error: e);
    }
  }

  static Future<void> showSubtitle(String text) async {
    if (text.trim().isEmpty) return;

    // UI Spam Protection (Throttle)
    final now = DateTime.now();
    if (_lastSubtitleUpdate != null &&
        now.difference(_lastSubtitleUpdate!).inMilliseconds < _throttleMilliseconds) {
      dev.log("Skipped subtitle update (throttled): $text", name: 'OverlayService');
      return;
    }

    try {
      if (!await FlutterOverlayWindow.isActive()) return;

      _lastSubtitleUpdate = now;
      await FlutterOverlayWindow.shareData(text);

    } catch (e) {
      dev.log("Error updating subtitle", name: 'OverlayService', error: e);
    }
  }

  static Future<void> syncPreferences(UserPreference prefs) async {
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData(prefs.toMap());
      }
    } catch (e) {
      dev.log("Error syncing prefs", name: 'OverlayService', error: e);
    }
  }

  static Future<void> syncPipelineStatus({required bool isRunning, required bool isPaused}) async {
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData({
          'type': 'status_update',
          'isRunning': isRunning,
          'isPaused': isPaused,
        });
      }
    } catch (e) {
      dev.log("Error syncing status", name: 'OverlayService', error: e);
    }
  }
}