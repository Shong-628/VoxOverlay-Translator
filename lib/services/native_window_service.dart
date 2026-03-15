// lib/services/native_window_service.dart
import 'package:flutter/services.dart';
import 'dart:developer' as dev;

class NativeWindowService {
  static const MethodChannel _channel = MethodChannel('vox_overlay/window');

  /// Forces the Android OS to bring the app to the foreground
  static Future<void> bringAppToForeground() async {
    try {
      await _channel.invokeMethod('bringToForeground');
      dev.log("App brought to foreground", name: "NativeWindow");
    } on PlatformException catch (e) {
      dev.log("Failed to bring app to foreground: '${e.message}'.", name: "NativeWindow");
    }
  }
}