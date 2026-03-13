// overlay_service.dart
import 'dart:developer' as dev;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';

class OverlayService {
  /// Check if overlay permission is granted
  static Future<bool> hasPermission() async {
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  /// Request overlay permission from the user
  static Future<void> requestPermission() async {
    await FlutterOverlayWindow.requestPermission();
  }

  /// Start the overlay window
  static Future<void> startOverlay() async {
    try {

      // 2. Existing Overlay (System Alert Window) permission check
      bool permission = await hasPermission();
      if (!permission) {
        await requestPermission();
        permission = await hasPermission();
        if (!permission) {
          dev.log("Overlay permission denied by user", name: 'OverlayService');
          return;
        }
      }

      bool isActive = await FlutterOverlayWindow.isActive();
      if (isActive) return;

      // 3. Start the overlay only after BOTH permissions are secured
      await FlutterOverlayWindow.showOverlay(
        height: 160,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.center,
        flag: OverlayFlag.defaultFlag,
        enableDrag: true,
      );

      dev.log("Overlay window started", name: 'OverlayService');
    } catch (e, stackTrace) {
      dev.log("Error starting overlay", name: 'OverlayService', error: e, stackTrace: stackTrace);
    }
  }

  /// Stop the overlay window
  static Future<void> stopOverlay() async {
    try {
      bool active = await FlutterOverlayWindow.isActive();
      if (!active) return;

      await FlutterOverlayWindow.closeOverlay();
      dev.log("Overlay window closed", name: 'OverlayService');
    } catch (e, stackTrace) {
      dev.log("Error closing overlay", name: 'OverlayService', error: e, stackTrace: stackTrace);
    }
  }

  /// Send subtitle text to the overlay
  /// Renamed to showSubtitle to match AudioPipelineService calls
  static Future<void> showSubtitle(String text) async {
    if (text.trim().isEmpty) return;

    try {
      bool active = await FlutterOverlayWindow.isActive();
      if (!active) {
        // Optional: Auto-start overlay if it's not active
        await startOverlay();
      }

      // Sends data to the overlay entry point
      await FlutterOverlayWindow.shareData(text);
      dev.log("Sent to overlay: $text", name: 'OverlayService');
    } catch (e, stackTrace) {
      dev.log("Error updating subtitle", name: 'OverlayService', error: e, stackTrace: stackTrace);
    }
  }
}