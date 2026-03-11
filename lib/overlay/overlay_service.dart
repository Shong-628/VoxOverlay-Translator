import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {

  // Check if overlay permission is granted
  static Future<bool> hasPermission() async {
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  // Request overlay permission
  static Future<void> requestPermission() async {
    await FlutterOverlayWindow.requestPermission();
  }

  // Start overlay window
  static Future<void> startOverlay() async {

    bool permission = await hasPermission();

    if (!permission) {
      await requestPermission();
      permission = await hasPermission();

      if (!permission) {
        throw Exception("Overlay permission not granted");
      }
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "VoxOverlay Translate",
      overlayContent: "Running",
      alignment: OverlayAlignment.center,
      height: 120,
      width: 300,
      flag: OverlayFlag.defaultFlag,
    );
  }

  // Stop overlay window
  static Future<void> stopOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  // Update subtitle text in overlay
  static Future<void> updateSubtitle(String text) async {
    await FlutterOverlayWindow.shareData(text);
  }
}