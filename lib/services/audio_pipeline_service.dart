import 'dart:async';
import 'dart:io';
import 'dart:developer' as dev;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../native_bridge.dart';
import 'whisper_service.dart';
import 'translation_service.dart'; //
import '../overlay/overlay_service.dart'; //

class AudioPipelineService {
  final WhisperService _whisperService = WhisperService();
  final TranslationService _translationService = TranslationService(); //
  final AudioRecorder _recorder = AudioRecorder();

  bool _running = false;
  String sourceLang = "en";
  String targetLang = "ms";

  bool get isRunning => _running;

  /// Initialize all required services
  Future<void> initialize() async {
    await _whisperService.initialize(); //
    await _translationService.loadModel(sourceLang, targetLang); //
    dev.log("Pipeline initialized", name: 'AudioPipeline');
  }

  /// Start continuous listening and translation loop
  Future<void> startPipeline() async {
    if (_running) return;
    _running = true;
    dev.log("Audio pipeline started", name: 'AudioPipeline');

    while (_running) {
      try {
        // 1. Capture Audio (Internal or Mic)
        final audioPath = await _captureAudio(); //

        if (audioPath == null || audioPath.isEmpty) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        // 2. Transcribe using Whisper
        final transcript = await _whisperService.transcribe(audioPath); //

        if (transcript.trim().isEmpty) {
          dev.log("Empty transcript, skipping...", name: 'AudioPipeline');
          continue;
        }

        dev.log("Transcript: $transcript", name: 'AudioPipeline');

        // 3. Translate using the updated Argos service
        final translated = await _translationService.translate(transcript); //
        dev.log("Translated ($targetLang): $translated", name: 'AudioPipeline');

        // 4. Update UI Overlay
        OverlayService.showSubtitle(translated); //

      } catch (e, stackTrace) {
        dev.log(
          "Audio pipeline loop error",
          name: 'AudioPipeline',
          error: e,
          stackTrace: stackTrace,
        );
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  /// Stop the loop
  void stopPipeline() {
    _running = false;
    dev.log("Audio pipeline stopped", name: 'AudioPipeline');
  }

  void togglePipeline() {
    if (_running) {
      stopPipeline();
    } else {
      startPipeline();
    }
  }

  /// Capture audio from internal source or microphone
  Future<String?> _captureAudio() async {
    try {
      // Check native bridge for internal audio path
      final internalPath = await NativeBridge.startInternalCapture(); //

      if (internalPath != null && internalPath.isNotEmpty) {
        if (await File(internalPath).exists()) {
          return internalPath;
        }
      }
    } catch (e) {
      dev.log("Internal capture failed", name: 'AudioPipeline', error: e);
    }

    // Fallback to microphone
    return await _captureMicAudio(); //
  }

  /// Microphone capture helper
  Future<String?> _captureMicAudio() async {
    try {
      if (!await _recorder.hasPermission()) return null; //

      final tempDir = await getTemporaryDirectory();
      final path = "${tempDir.path}/voxoverlay_mic.wav";

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav, //
          sampleRate: 16000,         //
          numChannels: 1,            //
        ),
        path: path,
      );

      // Listen for 4 seconds before processing
      await Future.delayed(const Duration(seconds: 4)); //
      return await _recorder.stop(); //
    } catch (e, stackTrace) {
      dev.log(
        "Mic capture error",
        name: 'AudioPipeline',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
