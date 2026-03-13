// lib/audio_pipeline_service.dart
import 'dart:async';
import 'dart:developer' as dev;
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
  final List<int> _audioBuffer = [];

  bool _running = false;
  bool get isRunning => _running;
  bool _isProcessing = false;

  static const int _targetBytesPerChunk = 32000 * 4;

  Future<void> initialize() async {
    await _whisperService.initialize();
  }

  Future<void> startPipeline() async {
    if (_running) return;
    if (!await _recorder.hasPermission()) return;

    _running = true;
    _isProcessing = false;
    _audioBuffer.clear();
    notifyListeners();

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _audioStreamSubscription = stream.listen((data) {
      _audioBuffer.addAll(data);
      if (_audioBuffer.length >= _targetBytesPerChunk && !_isProcessing) {
        _processAudioChunk();
      }
    });
  }

  Future<void> _processAudioChunk() async {
    if (!_running || _audioBuffer.isEmpty) return;

    _isProcessing = true;

    try {
      // 1. Extract bytes and clear buffer instantly
      final chunkBytes = Uint8List.fromList(_audioBuffer);
      _audioBuffer.clear();

      // 2. Convert 16-bit PCM Ints to 32-bit Floats (Expected by Whisper)
      // Normalizing the int16 (-32768 to 32767) to float32 (-1.0 to 1.0)
      final int16List = chunkBytes.buffer.asInt16List();
      final floatList = List<double>.filled(int16List.length, 0.0);
      for (int i = 0; i < int16List.length; i++) {
        floatList[i] = int16List[i] / 32768.0;
      }

      // 3. Transcribe directly from RAM
      final transcript = await _whisperService.transcribe(floatList);

      if (!_running || transcript.trim().isEmpty) return;

      // 4. Translate & Update UI
      final translated = await _translationService.translate(transcript);
      if (_running) {
        dev.log("PIPELINE OUTPUT: '$translated'");
        OverlayService.showSubtitle(translated);
      }
    } catch (e) {
      dev.log("Pipeline error", name: 'AudioPipeline', error: e);
    } finally {
      _isProcessing = false;
      if (_audioBuffer.length >= _targetBytesPerChunk && _running) {
        _processAudioChunk(); // Catch up if buffer filled during processing
      }
    }
  }

  Future<void> stopPipeline() async {
    _running = false;
    await _audioStreamSubscription?.cancel();
    await _recorder.stop();
    _audioBuffer.clear();
    _isProcessing = false;
    notifyListeners();
  }

  void togglePipeline() {
    _running ? stopPipeline() : startPipeline();
  }
}