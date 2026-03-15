import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../db/database_helper.dart';
import '../models/user_preference.dart';

class OverlayService {
  static Completer<bool>? _overlayReadyCompleter;

  static void handleSystemMessage(dynamic data) {
    if (data is Map && data['status'] == 'ready') {
      if (_overlayReadyCompleter != null && !_overlayReadyCompleter!.isCompleted) {
        _overlayReadyCompleter!.complete(true);
        dev.log("Overlay ping received: Ready!", name: 'OverlayService');
      }
    }
  }

  static Future<bool> hasPermission() async {
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  static Future<void> requestPermission() async {
    await FlutterOverlayWindow.requestPermission();
  }

  static Future<void> startOverlay() async {
    try {
      bool permission = await hasPermission();
      if (!permission) {
        await requestPermission();
        if (!await hasPermission()) return;
      }

      bool isActive = await FlutterOverlayWindow.isActive();
      if (isActive) return;

      _overlayReadyCompleter = Completer<bool>();

      await FlutterOverlayWindow.showOverlay(
        height: 160,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.center,
        flag: OverlayFlag.defaultFlag,
        enableDrag: true,
      );

      // Wait for the OverlayApp to initialize and send the 'ready'
      // ping before blasting the preferences over the channel.
      try {
        await _overlayReadyCompleter!.future.timeout(const Duration(seconds: 5));
      } catch (e) {
        dev.log("Timeout waiting for overlay to be ready.", name: 'OverlayService');
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
    } catch (e) {
      dev.log("Error closing overlay", name: 'OverlayService', error: e);
    }
  }

  static Future<void> showSubtitle(String text) async {
    if (text.trim().isEmpty) return;

    try {
      if (!await FlutterOverlayWindow.isActive()) {
        await startOverlay();
      }

      await FlutterOverlayWindow.shareData(text);
    } catch (e) {
      dev.log("Error updating subtitle", name: 'OverlayService', error: e);
    }
  }

  static Future<void> syncPreferences(UserPreference prefs) async {
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData(prefs.toMap());
        dev.log("Preferences synced to overlay.", name: 'OverlayService');
      }
    } catch (e) {
      dev.log("Error syncing prefs", name: 'OverlayService', error: e);
    }
  }
}