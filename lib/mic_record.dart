// mic_record.dart
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

final recorder = AudioRecorder();

Future<String> captureAudio() async {
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