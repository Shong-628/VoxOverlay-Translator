// lib/audio_pipeline_service.dart
import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'whisper_service.dart';
import 'translation_service.dart';
import '../overlay/overlay_service.dart';

class AudioPipelineService extends ChangeNotifier {
  final WhisperService _whisperService = WhisperService();
  final TranslationService _translationService = TranslationService();
  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Uint8List>? _audioStreamSubscription;

  // Buffer for incoming raw bytes
  final List<int> _byteBuffer = [];

  // Context buffer for streaming decoder (holds past X seconds of floats)
  final List<double> _contextBuffer = [];

  bool _running = false;
  bool get isRunning => _running;
  bool _isProcessing = false;

  // Configuration for real-time streaming
  static const int _sampleRate = 16000;
  static const int _minChunkBytes = 16000; // Trigger processing every 0.5s (16k bytes)
  static const int _maxContextSamples = _sampleRate * 12; // Max 12 seconds of context

  // Silence Detection (VAD)
  int _silenceChunks = 0;
  static const double _silenceThreshold = 0.01; // Adjust based on mic sensitivity
  static const int _maxSilenceChunks = 3; // Clear buffer after ~1.5s of silence

  Future<void> initialize() async {
    await _whisperService.initialize();
  }

  Future<void> startPipeline() async {
    if (_running) return;
    if (!await _recorder.hasPermission()) return;

    _running = true;
    _isProcessing = false;
    _byteBuffer.clear();
    _contextBuffer.clear();
    _silenceChunks = 0;

    // Ensure translation cache is completely fresh on start
    _translationService.resetCache();

    notifyListeners();

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );

    _audioStreamSubscription = stream.listen((data) {
      _byteBuffer.addAll(data);
      // Trigger processing rapidly for real-time feel
      if (_byteBuffer.length >= _minChunkBytes && !_isProcessing) {
        _processAudioChunk();
      }
    });
  }

  Future<void> _processAudioChunk() async {
    if (!_running || _byteBuffer.isEmpty) return;

    _isProcessing = true;

    try {
      // 1. Extract all available bytes (handles varying inference times dynamically)
      // Ensure we grab an even number of bytes for 16-bit PCM conversion
      int bytesToTake = _byteBuffer.length - (_byteBuffer.length % 2);
      final chunkBytes = Uint8List.fromList(_byteBuffer.sublist(0, bytesToTake));
      _byteBuffer.removeRange(0, bytesToTake);

      // 2. Convert to Floats and calculate RMS (Volume/Energy)
      final int16List = chunkBytes.buffer.asInt16List();
      final floatList = List<double>.filled(int16List.length, 0.0);

      double sumSquares = 0.0;
      for (int i = 0; i < int16List.length; i++) {
        double floatVal = int16List[i] / 32768.0;
        floatList[i] = floatVal;
        sumSquares += floatVal * floatVal;
      }

      double rms = math.sqrt(sumSquares / int16List.length);

      // 3. Handle Silence / VAD
      if (rms < _silenceThreshold) {
        _silenceChunks++;
      } else {
        _silenceChunks = 0;
      }

      // If silent for a while, clear context to start a fresh sentence
      if (_silenceChunks >= _maxSilenceChunks) {
        if (_contextBuffer.isNotEmpty) {
          dev.log("Silence detected. Clearing context buffer.", name: 'AudioPipeline');
          _contextBuffer.clear();

          // CRITICAL: Reset translation cache so identical future sentences aren't ignored
          _translationService.resetCache();
        }
        _isProcessing = false;
        return; // Skip transcription on empty silence
      }

      // 4. Update Context Window
      _contextBuffer.addAll(floatList);
      if (_contextBuffer.length > _maxContextSamples) {
        // Slide the window forward, dropping the oldest samples
        _contextBuffer.removeRange(0, _contextBuffer.length - _maxContextSamples);
      }

      // 5. Transcribe Context Window
      final transcript = await _whisperService.transcribe(Float32List.fromList(_contextBuffer));

      if (!_running || transcript.trim().isEmpty) return;

      // Filter out common Whisper hallucination tags
      final cleanTranscript = transcript.replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), '').trim();
      if (cleanTranscript.isEmpty) return;

      // 6. Translate & Update UI continuously (Streaming output)
      final translated = await _translationService.translate(cleanTranscript);
      if (_running && translated.isNotEmpty) {
        dev.log("STREAM OUTPUT: '$translated'");
        OverlayService.showSubtitle(translated);
      }

    } catch (e) {
      dev.log("Pipeline error", name: 'AudioPipeline', error: e);
    } finally {
      _isProcessing = false;
      // Safely catch up immediately if audio piled up using the event loop
      if (_byteBuffer.length >= _minChunkBytes && _running) {
        Future.microtask(() => _processAudioChunk());
      }
    }
  }

  Future<void> stopPipeline() async {
    _running = false;
    await _audioStreamSubscription?.cancel();
    await _recorder.stop();
    _byteBuffer.clear();
    _contextBuffer.clear();
    _isProcessing = false;

    // CRITICAL: Clear cache so the next session starts fresh
    _translationService.resetCache();

    notifyListeners();
  }

  void togglePipeline() {
    _running ? stopPipeline() : startPipeline();
  }
}