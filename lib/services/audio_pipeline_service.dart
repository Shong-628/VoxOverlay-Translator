// lib/services/audio_pipeline_service.dart
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
  final TranslationService _translationService; // Shared instance
  final AudioRecorder _recorder = AudioRecorder();

  // Use named parameter to avoid positional mismatch and improve clarity
  AudioPipelineService({required TranslationService translationService})
      : _translationService = translationService;

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
  static const int _minChunkBytes = 8000; // Process every 0.25s
  static const int _maxContextSamples = _sampleRate * 8; // Keep context to 8s

  // Silence Detection (VAD)
  int _silenceChunks = 0;
  static const double _silenceThreshold = 0.008;
  static const int _maxSilenceChunks = 2; // Reset context after ~0.5s of silence

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
      if (_byteBuffer.length >= _minChunkBytes && !_isProcessing) {
        _processAudioChunk();
      }
    });
  }

  Future<void> _processAudioChunk() async {
    if (!_running || _byteBuffer.isEmpty) return;

    _isProcessing = true;

    try {
      int bytesToTake = _byteBuffer.length - (_byteBuffer.length % 2);
      final chunkBytes = Uint8List.fromList(_byteBuffer.sublist(0, bytesToTake));
      _byteBuffer.removeRange(0, bytesToTake);

      final int16List = chunkBytes.buffer.asInt16List();
      final floatList = List<double>.filled(int16List.length, 0.0);

      double sumSquares = 0.0;
      for (int i = 0; i < int16List.length; i++) {
        double floatVal = int16List[i] / 32768.0;
        floatList[i] = floatVal;
        sumSquares += floatVal * floatVal;
      }

      double rms = math.sqrt(sumSquares / int16List.length);

      // 1. Update VAD State
      if (rms < _silenceThreshold) {
        _silenceChunks++;
      } else {
        _silenceChunks = 0;
      }

      // 2. Manage Context Window
      _contextBuffer.addAll(floatList);
      if (_contextBuffer.length > _maxContextSamples) {
        _contextBuffer.removeRange(0, _contextBuffer.length - _maxContextSamples);
      }

      bool isEndOfSentence = _silenceChunks >= _maxSilenceChunks;

      // 3. Run Transcription
      if (_silenceChunks < _maxSilenceChunks || (isEndOfSentence && _contextBuffer.isNotEmpty)) {
        final transcript = await _whisperService.transcribe(Float32List.fromList(_contextBuffer));
        
        if (_running && transcript.trim().isNotEmpty) {
          final cleanTranscript = transcript.replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), '').trim();
          
          if (cleanTranscript.isNotEmpty) {
            final translated = await _translationService.translate(cleanTranscript);
            if (_running && translated.isNotEmpty) {
              OverlayService.showSubtitle(translated);
            }
          }
        }
      }

      // 4. Cleanup Context if silence detected
      if (isEndOfSentence && _contextBuffer.isNotEmpty) {
        dev.log("Sentence break. Clearing context.", name: 'AudioPipeline');
        _contextBuffer.clear();
        _translationService.resetCache();
      }

    } catch (e) {
      dev.log("Pipeline error", name: 'AudioPipeline', error: e);
    } finally {
      _isProcessing = false;
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
    _translationService.resetCache();
    notifyListeners();
  }

  void togglePipeline() {
    _running ? stopPipeline() : startPipeline();
  }
}
