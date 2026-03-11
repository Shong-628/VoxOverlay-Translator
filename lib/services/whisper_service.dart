import 'package:flutter/services.dart';

class WhisperService {

  static const platform =
  MethodChannel("voxoverlay/whisper");

  static Future<String> transcribe(String path) async {

    final result = await platform.invokeMethod(
      "transcribe",
      {"path": path},
    );

    return result;
  }
}