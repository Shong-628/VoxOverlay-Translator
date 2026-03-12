// native_bridge.dart
import 'package:flutter/services.dart';
import 'dart:developer' as dev;

class NativeBridge {
  static const channel = MethodChannel("voxoverlay/audio");

  /// Starts internal capture and returns the path to the recorded file
  static Future<String?> startInternalCapture() async {
    try {
      // The native side should return the String path of the saved file
      final String? path = await channel.invokeMethod<String>("startInternalCapture");
      return path;
    } catch (e, stackTrace) {
      dev.log(
        "Native bridge capture failed",
        name: 'NativeBridge',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}