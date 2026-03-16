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
  final TranslationService _translationService;
  final AudioRecorder _recorder = AudioRecorder();

  AudioPipelineService({required TranslationService translationService})
      : _translationService = translationService;

  StreamSubscription<Uint8List>? _audioStreamSubscription;

  // Raw byte buffer from the microphone
  final List<int> _byteBuffer = [];
  // Normalized float buffer for Whisper inference
  final List<double> _contextBuffer = [];

  bool _running = false;
  bool get isRunning => _running;

  bool _isProcessing = false;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  // BACKEND LOCK: Prevents overlapping start/stop calls
  bool _isTransitioning = false;

  // IMPORTANT VALUES FOR OPTIMIZATION AND PERFORMANCE
  static const int _sampleRate = 16000;

  // Chunk size: 48,000 bytes = 1.5 seconds of audio.
  // Optimal for Snapdragon 680 to process quickly without lagging.
  static const int _minChunkBytes = 48000;

  // OPPO A96 OPTIMIZATION: Max 5 seconds of continuous audio (80,000 floats)
  // Prevents the CPU from choking on massive inference tasks. Forces shorter sentences.
  static const int _maxContextSamples = _sampleRate * 5;

  // OPPO A96 OPTIMIZATION: Safety cap set to 4 seconds of raw audio backlog (128,000 bytes).
  // If the processor stalls and falls 4 seconds behind, we act as a pressure relief valve
  // and drop the oldest bytes. This prevents "infinite latency" freezes.
  static const int _maxBufferBytes = 128000;

  int _silenceChunks = 0;
  static const double _silenceThreshold = 0.008;
  static const int _maxSilenceChunks = 2;

  // Tracks the last sent subtitle to prevent platform channel spam
  String _lastSubtitle = "";

  Future<void> initialize() async {
    await _whisperService.initialize();
  }

  String _mapToWhisperLang(String prefLang) {
    final l = prefLang.toLowerCase();
    if (l == 'english' || l == 'en') return 'en';
    if (l == 'malay' || l == 'ms') return 'ms';
    if (l == 'chinese' || l == 'zh') return 'zh';
    return 'auto';
  }

  Future<void> startPipeline() async {
    if (_running || _isTransitioning) return;
    _isTransitioning = true;

    try {
      if (!await _recorder.hasPermission()) return;

      _running = true;
      _isPaused = false;
      _isProcessing = false;
      _byteBuffer.clear();
      _contextBuffer.clear();
      _silenceChunks = 0;
      _lastSubtitle = "";

      _translationService.resetCache();

      OverlayService.syncPipelineStatus(isRunning: true, isPaused: false);
      notifyListeners();

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );

      _audioStreamSubscription = stream.listen((data) {
        if (_isPaused) return;
        _byteBuffer.addAll(data);

        // PRESSURE RELIEF VALVE
        // Drops oldest bytes in pairs (to maintain 16-bit PCM alignment) if we hit the 4-second cap.
        if (_byteBuffer.length > _maxBufferBytes) {
          int overflow = _byteBuffer.length - _maxBufferBytes;
          if (overflow % 2 != 0) overflow += 1;

          _byteBuffer.removeRange(0, overflow);
          dev.log("CPU bottleneck on SD680: Dropped $overflow bytes to maintain real-time sync.", name: "AudioPipeline");
        }

        if (_byteBuffer.length >= _minChunkBytes && !_isProcessing) {
          _processAudioChunk();
        }
      });
    } catch (e) {
      dev.log("Error starting pipeline", name: 'AudioPipeline', error: e);
      _running = false;
      notifyListeners();
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _processAudioChunk() async {
    if (!_running || _isPaused || _byteBuffer.isEmpty) return;
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

      if (rms < _silenceThreshold) {
        _silenceChunks++;
      } else {
        _silenceChunks = 0;
      }

      _contextBuffer.addAll(floatList);

      bool isEndOfSentence = _silenceChunks >= _maxSilenceChunks;
      bool isBufferFull = _contextBuffer.length >= _maxContextSamples;

      // Trigger inference on silence OR if we hit our 5-second context limit
      if ((isEndOfSentence || isBufferFull) && _contextBuffer.isNotEmpty) {

        if (_contextBuffer.length > _maxContextSamples) {
          _contextBuffer.removeRange(0, _contextBuffer.length - _maxContextSamples);
        }

        String currentSourceLang = _translationService.sourcePref;
        String whisperLang = _mapToWhisperLang(currentSourceLang);

        final transcript = await _whisperService.transcribe(
          Float32List.fromList(_contextBuffer),
          language: whisperLang,
        );

        if (_running && transcript.trim().isNotEmpty) {
          final cleanTranscript = transcript.replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), '').trim();

          if (cleanTranscript.isNotEmpty) {
            String displayText = cleanTranscript;

            if (!_translationService.bypassTranslation) {
              displayText = await _translationService.translate(cleanTranscript);
            }

            if (_running && displayText.isNotEmpty && displayText != _lastSubtitle) {
              _lastSubtitle = displayText;
              OverlayService.showSubtitle(displayText);
            }
          }
        }

        _contextBuffer.clear();
        _translationService.resetCache();
        _lastSubtitle = "";
        _silenceChunks = 0;
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
    if (!_running || _isTransitioning) return;

    _isTransitioning = true;
    _running = false;

    try {
      await _audioStreamSubscription?.cancel();
      await _recorder.stop();

      _byteBuffer.clear();
      _contextBuffer.clear();
      _lastSubtitle = "";
      _isProcessing = false;
      _translationService.resetCache();

      OverlayService.syncPipelineStatus(isRunning: false, isPaused: false);
      notifyListeners();
    } catch (e) {
      dev.log("Error stopping pipeline", name: 'AudioPipeline', error: e);
    } finally {
      _isTransitioning = false;
    }
  }

  void togglePipeline() {
    if (_isTransitioning) return;

    if (!_running) {
      startPipeline();
    } else {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _byteBuffer.clear();
        _contextBuffer.clear();
        _lastSubtitle = "";
      }
      OverlayService.syncPipelineStatus(isRunning: _running, isPaused: _isPaused);
      notifyListeners();
    }
  }

  void forcePause() {
    if (_running && !_isPaused && !_isTransitioning) {
      _isPaused = true;
      OverlayService.syncPipelineStatus(isRunning: _running, isPaused: _isPaused);
      notifyListeners();
    }
  }
}