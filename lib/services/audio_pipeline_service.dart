// audio_pipeline_service.dart
import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'whisper_service.dart';
import 'translation_service.dart';
import '../overlay/overlay_service.dart';

class AudioPipelineService extends ChangeNotifier {
  final WhisperService _whisperService = WhisperService();
  final TranslationService _translationService = TranslationService();
  final AudioRecorder _recorder = AudioRecorder();

  bool _running = false;
  bool get isRunning => _running;

  Future<void> initialize() async {
    await _whisperService.initialize();
    dev.log("Pipeline initialized", name: 'AudioPipeline');
  }

  Future<void> startPipeline() async {
    if (_running) return;

    _running = true;
    notifyListeners();
    dev.log("Audio pipeline started", name: 'AudioPipeline');

    while (_running) {
      try {
        final audioPath = await _captureAudio();

        if (audioPath == null || audioPath.isEmpty) {
          if (_running) await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        // 1. TRANSCRIPTION
        final transcript = await _whisperService.transcribe(audioPath);

        if (!_running) return;

        if (transcript.trim().isEmpty) {
          dev.log("Empty transcript, skipping...", name: 'AudioPipeline');
          continue;
        }

        // 2. TRANSLATION
        final translated = await _translationService.translate(transcript);

        dev.log("PIPELINE OUTPUT: '$translated'");

        // 3. UI Updates
        OverlayService.showSubtitle(translated);

      } catch (e, stackTrace) {
        dev.log(
          "Audio pipeline loop error",
          name: 'AudioPipeline',
          error: e,
          stackTrace: stackTrace,
        );

        // Prevent rapid error looping
        if (_running) await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  void stopPipeline() {
    _running = false;
    notifyListeners();
    dev.log("Audio pipeline stopped", name: 'AudioPipeline');
  }

  void togglePipeline() {
    if (_running) {
      stopPipeline();
    } else {
      startPipeline();
    }
  }

  /// Capture audio directly from microphone
  Future<String?> _captureAudio() async {
    return await _captureMicAudio();
  }

  Future<String?> _captureMicAudio() async {
    try {
      // Internal check for permission, but UI handles the request/denial logic
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
      if (!_running) {
        await _recorder.stop();
        return null;
      }
      return await _recorder.stop();
    } catch (e) {
      return null;
    }
  }
}
