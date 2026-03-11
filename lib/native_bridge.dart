import 'package:flutter/services.dart';

class NativeBridge {

  static const channel = MethodChannel("voxoverlay/native");

  static Future<String> transcribe(String path) async {

    final text = await channel.invokeMethod(
      "transcribe",
      {"path": path},
    );

    return text;
  }
}