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

  AudioPipelineService({required TranslationService translationService})
      : _translationService = translationService;

  StreamSubscription<Uint8List>? _audioStreamSubscription;

  final List<int> _byteBuffer = [];
  final List<double> _contextBuffer = [];

  bool _running = false;
  bool get isRunning => _running;
  bool _isProcessing = false;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  static const int _sampleRate = 16000;
  static const int _minChunkBytes = 8000; // Process every 0.25s
  static const int _maxContextSamples = _sampleRate * 8; 

  int _silenceChunks = 0;
  static const double _silenceThreshold = 0.008;
  static const int _maxSilenceChunks = 2; 

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
    if (_running) return;
    if (!await _recorder.hasPermission()) return;

    _running = true;
    _isPaused = false;
    _isProcessing = false;
    _byteBuffer.clear();
    _contextBuffer.clear();
    _silenceChunks = 0;

    _translationService.resetCache();
    
    // Sync status to overlay
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
      if (_byteBuffer.length >= _minChunkBytes && !_isProcessing) {
        _processAudioChunk();
      }
    });
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
      if (_contextBuffer.length > _maxContextSamples) {
        _contextBuffer.removeRange(0, _contextBuffer.length - _maxContextSamples);
      }

      bool isEndOfSentence = _silenceChunks >= _maxSilenceChunks;

      if (_silenceChunks < _maxSilenceChunks || (isEndOfSentence && _contextBuffer.isNotEmpty)) {
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
            if (_running && displayText.isNotEmpty) {
              OverlayService.showSubtitle(displayText);
            }
          }
        }
      }

      if (isEndOfSentence && _contextBuffer.isNotEmpty) {
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
    
    // Sync status to overlay
    OverlayService.syncPipelineStatus(isRunning: false, isPaused: false);
    notifyListeners();
  }

  void togglePipeline() {
    if (!_running) {
      startPipeline();
    } else {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _byteBuffer.clear();
        _contextBuffer.clear();
      }
      
      // Sync status to overlay
      OverlayService.syncPipelineStatus(isRunning: _running, isPaused: _isPaused);
      notifyListeners();
    }
  }

  void forcePause() {
    if (_running && !_isPaused) {
      _isPaused = true;
      OverlayService.syncPipelineStatus(isRunning: _running, isPaused: _isPaused);
      notifyListeners();
    }
  }
}
