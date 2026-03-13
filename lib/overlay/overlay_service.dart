// overlay_service.dart
import 'dart:async'; // Added for Completer
import 'dart:developer' as dev;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db/database_helper.dart';

class OverlayService {
  /// Holds the pending state while the overlay boots
  static Completer<bool>? _overlayReadyCompleter;

  /// Processes incoming system-level pings from the overlay
  static void handleSystemMessage(dynamic data) {
    if (data is Map && data['status'] == 'ready') {
      if (_overlayReadyCompleter != null && !_overlayReadyCompleter!.isCompleted) {
        _overlayReadyCompleter!.complete(true);
        dev.log("Overlay ping received: Ready!", name: 'OverlayService');
      }
    }
  }

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
      // Existing Overlay (System Alert Window) permission check
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

      // Initialize a fresh Completer right before starting the overlay
      _overlayReadyCompleter = Completer<bool>();

      // Start the overlay only after BOTH permissions are secured
      await FlutterOverlayWindow.showOverlay(
        height: 160,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.center,
        flag: OverlayFlag.defaultFlag,
        enableDrag: true,
      );

      final prefs = await DatabaseHelper.instance.getPreferences();
      await FlutterOverlayWindow.shareData(prefs.toMap());

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
  static Future<void> showSubtitle(String text) async {
    if (text.trim().isEmpty) return;

    try {
      bool active = await FlutterOverlayWindow.isActive();
      if (!active) {
        await startOverlay();

        // Safely wait for the overlay to signal it is ready
        if (_overlayReadyCompleter != null) {
          // Use a timeout to prevent the app from hanging if the overlay crashes
          await _overlayReadyCompleter!.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              dev.log("Overlay boot timeout - proceeding anyway", name: 'OverlayService');
              return false;
            },
          );
        }
      }

      // Sends data to the overlay entry point
      await FlutterOverlayWindow.shareData(text);
      dev.log("Sent to overlay: $text", name: 'OverlayService');
    } catch (e, stackTrace) {
      dev.log("Error updating subtitle", name: 'OverlayService', error: e, stackTrace: stackTrace);
    }
  }
}