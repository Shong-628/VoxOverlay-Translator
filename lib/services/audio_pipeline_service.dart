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

  static const int _sampleRate = 16000;
  static const int _minChunkBytes = 48000; // Process roughly every 1.5s
  static const int _maxContextSamples = _sampleRate * 8; // Max 8 seconds of continuous audio

  // Safety cap to prevent unbounded memory growth if processing stalls (~2 seconds of raw audio)
  static const int _maxBufferBytes = 64000;

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
    // BACKEND LOCK CHECK: Reject if already running or currently starting/stopping
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

      // Sync status to overlay immediately
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

        // FIX 1: PCM Misalignment Bug
        // If the processing is stalling, drop oldest bytes to prevent memory leaks.
        // We MUST ensure we drop an EVEN number of bytes because 16-bit PCM uses 2 bytes per sample.
        // Dropping an odd number corrupts the entire audio stream into static.
        if (_byteBuffer.length > _maxBufferBytes) {
          int overflow = _byteBuffer.length - _maxBufferBytes;
          if (overflow % 2 != 0) overflow += 1; // Round up to nearest even number

          _byteBuffer.removeRange(0, overflow);
          dev.log("Pipeline stalled: Dropped $overflow bytes to protect memory alignment.", name: "AudioPipeline");
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
      // Release lock
      _isTransitioning = false;
    }
  }

  Future<void> _processAudioChunk() async {
    if (!_running || _isPaused || _byteBuffer.isEmpty) return;
    _isProcessing = true;

    try {
      // Ensure we take an even number of bytes for 16-bit PCM
      int bytesToTake = _byteBuffer.length - (_byteBuffer.length % 2);
      final chunkBytes = Uint8List.fromList(_byteBuffer.sublist(0, bytesToTake));
      _byteBuffer.removeRange(0, bytesToTake);

      // Convert bytes to Int16, then normalize to floats between -1.0 and 1.0 for Whisper
      final int16List = chunkBytes.buffer.asInt16List();
      final floatList = List<double>.filled(int16List.length, 0.0);

      double sumSquares = 0.0;
      for (int i = 0; i < int16List.length; i++) {
        double floatVal = int16List[i] / 32768.0;
        floatList[i] = floatVal;
        sumSquares += floatVal * floatVal;
      }

      // Calculate Root Mean Square (RMS) to detect silence
      double rms = math.sqrt(sumSquares / int16List.length);

      if (rms < _silenceThreshold) {
        _silenceChunks++;
      } else {
        _silenceChunks = 0;
      }

      _contextBuffer.addAll(floatList);

      // FIX 2: "Never-Ending Sentence" Bug
      // Check if we hit the silence threshold OR if the buffer is simply too large.
      // This prevents data loss when a user talks continuously without pausing.
      bool isEndOfSentence = _silenceChunks >= _maxSilenceChunks;
      bool isBufferFull = _contextBuffer.length >= _maxContextSamples;

      // Trigger transcription if silent, or if we are about to overflow the context buffer
      if ((isEndOfSentence || isBufferFull) && _contextBuffer.isNotEmpty) {

        // Final safety check: trim buffer exactly to max size before inference just in case
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
          // Strip out non-speech tags like [Music] or (Coughs)
          final cleanTranscript = transcript.replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), '').trim();

          if (cleanTranscript.isNotEmpty) {
            String displayText = cleanTranscript;

            // Pass through Translation Service (which has its own zero-latency cache & bypass logic)
            if (!_translationService.bypassTranslation) {
              displayText = await _translationService.translate(cleanTranscript);
            }

            // FIX 3: Overlay Spam Protection
            // Only trigger the platform channel if the text has actually changed
            if (_running && displayText.isNotEmpty && displayText != _lastSubtitle) {
              _lastSubtitle = displayText;
              OverlayService.showSubtitle(displayText);
            }
          }
        }

        // Clean up buffers and cache once a sentence is completed to prepare for the next
        _contextBuffer.clear();
        _translationService.resetCache();
        _lastSubtitle = "";
        _silenceChunks = 0;
      }
    } catch (e) {
      dev.log("Pipeline error", name: 'AudioPipeline', error: e);
    } finally {
      _isProcessing = false;
      // If data piled up in the byte buffer while Whisper was processing, immediately schedule another pass
      if (_byteBuffer.length >= _minChunkBytes && _running) {
        Future.microtask(() => _processAudioChunk());
      }
    }
  }

  Future<void> stopPipeline() async {
    // BACKEND LOCK CHECK: Reject if already stopped or currently transitioning
    if (!_running || _isTransitioning) return;

    _isTransitioning = true;
    _running = false; // Immediately set to false to interrupt chunk processing loops

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
      // Release lock
      _isTransitioning = false;
    }
  }

  void togglePipeline() {
    // Prevent toggling if a start or stop is actively resolving
    if (_isTransitioning) return;

    if (!_running) {
      startPipeline();
    } else {
      _isPaused = !_isPaused;
      if (_isPaused) {
        // Clear buffers so unpausing starts fresh instead of translating old stale audio
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