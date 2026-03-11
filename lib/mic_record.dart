import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'native_bridge.dart';
import 'package:record/record.dart';

final recorder = AudioRecorder();

Future<String> captureAudio() async {
  // Use official bridge name from your file
  String? internalPath = await NativeBridge.startInternalCapture();

  // If the path isn't null, the native capture started/finished successfully
  if (internalPath != null) {
    // Use the path returned by the bridge rather than hardcoding it
    return internalPath;
  }

  // Get a proper temporary directory for the microphone fallback
  final tempDir = await getTemporaryDirectory();
  final String wavPath = "${tempDir.path}/mic_audio.wav";

  if (await recorder.hasPermission()) {
    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav, // Whisper needs WAV
        sampleRate: 16000,         // Whisper needs 16kHz
        numChannels: 1,            // Whisper needs Mono
      ),
      path: wavPath,
    );

    // Recording for 5 seconds as per your logic
    await Future.delayed(const Duration(seconds: 5));
    final path = await recorder.stop();
    return path ?? "";
  }

  return "";
}