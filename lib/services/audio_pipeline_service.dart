// audio_pipeline_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:developer' as dev;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../native_bridge.dart';
import 'whisper_service.dart';
import 'translation_service.dart';
import '../overlay/overlay_service.dart';

class AudioPipelineService {
  final WhisperService _whisperService = WhisperService();
  final TranslationService _translationService = TranslationService();
  final AudioRecorder _recorder = AudioRecorder();

  bool _running = false;
  String sourceLang = "en";
  String targetLang = "ms";

  bool get isRunning => _running;

  Future<void> initialize() async {
    await _whisperService.initialize();
    await _translationService.loadModel(sourceLang, targetLang);
    dev.log("Pipeline initialized", name: 'AudioPipeline');
  }

  Future<void> startPipeline() async {
    if (_running) return;
    _running = true;
    dev.log("Audio pipeline started", name: 'AudioPipeline');

    while (_running) {
      try {
        final audioPath = await _captureAudio();

        if (audioPath == null || audioPath.isEmpty) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        // TRANSCRIPTION
        // Note: If internalPath ends in .pcm, ensure Whisper handles raw 16kHz PCM.
        final transcript = await _whisperService.transcribe(audioPath);

        if (!_running) return;

        if (transcript.trim().isEmpty) {
          dev.log("Empty transcript, skipping...", name: 'AudioPipeline');
          continue;
        }

        // TRANSLATION
        final translated = await _translationService.translate(transcript);

        // UI
        OverlayService.showSubtitle(translated);

      } catch (e, stackTrace) {
        dev.log("Audio pipeline loop error", name: 'AudioPipeline', error: e, stackTrace: stackTrace);
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  void stopPipeline() {
    _running = false;
    _whisperService.dispose(); // This triggers the auto-stop and file cleanup
    dev.log("Audio pipeline stopped", name: 'AudioPipeline');
  }

  void togglePipeline() {
    if (_running) stopPipeline(); else startPipeline();
  }

  Future<String?> _captureAudio() async {
    try {
      final internalPath = await NativeBridge.startInternalCapture();

      if (internalPath != null && internalPath.isNotEmpty) {
        // IMPORTANT: Wait for the Native Service to finish its 5-second timer
        // and close the FileOutputStream.
        await Future.delayed(const Duration(milliseconds: 5500));

        if (await File(internalPath).exists()) {
          return internalPath;
        }
      }
    } catch (e) {
      dev.log("Internal capture failed, falling back to mic", name: 'AudioPipeline');
    }

    return await _captureMicAudio();
  }

  Future<String?> _captureMicAudio() async {
    try {
      if (!await _recorder.hasPermission()) return null;

      final tempDir = await getTemporaryDirectory();
      final path = "${tempDir.path}/voxoverlay_mic.wav";

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      await Future.delayed(const Duration(seconds: 5));
      return await _recorder.stop();
    } catch (e) {
      return null;
    }
  }
}