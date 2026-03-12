// mic_record.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'native_bridge.dart';
import 'package:record/record.dart';

final recorder = AudioRecorder();

Future<String> captureAudio() async {
  // 1. Try Internal Capture
  String? internalPath = await NativeBridge.startInternalCapture();

  if (internalPath != null) {
    // The native side (ProjectionService) stops itself after 5 seconds.
    // We must wait here for the native recording to finish before returning the path
    // so Whisper doesn't try to read an empty/incomplete file.
    await Future.delayed(const Duration(milliseconds: 5200));

    if (await File(internalPath).exists()) {
      return internalPath;
    }
  }

  // 2. Fallback to Mic
  final tempDir = await getTemporaryDirectory();
  final String wavPath = "${tempDir.path}/mic_audio.wav";

  if (await recorder.hasPermission()) {
    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: wavPath,
    );

    await Future.delayed(const Duration(seconds: 5));
    final path = await recorder.stop();
    return path ?? "";
  }

  return "";
}