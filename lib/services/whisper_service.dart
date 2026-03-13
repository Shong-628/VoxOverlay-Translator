// lib/whisper_service.dart
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../whisper_ffi.dart';
import 'dart:typed_data';

class WhisperService {
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal();

  final WhisperFFI _whisperFFI = WhisperFFI();

  bool _initialized = false;
  bool _isInitializing = false;
  bool _isTranscribing = false;

  Future<void> initialize() async {
    if (_initialized || _isInitializing) return;
    _isInitializing = true;

    try {
      dev.log("Initializing Native Whisper...", name: 'WhisperService');
      final modelPath = await _ensureModelIsReady();

      _initialized = _whisperFFI.init(modelPath);

      if (_initialized) {
        dev.log("Native Whisper initialized successfully.", name: 'WhisperService');
      } else {
        dev.log("FFI returned null context.", name: 'WhisperService');
      }
    } catch (e) {
      dev.log("Failed to init native Whisper", name: 'WhisperService', error: e);
    } finally {
      _isInitializing = false;
    }
  }

  Future<String> _ensureModelIsReady() async {
    final docDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${docDir.path}/ggml-tiny.bin');

    if (!await modelFile.exists() || await modelFile.length() < 5 * 1024 * 1024) {
      dev.log("Copying Whisper model to local storage...", name: 'WhisperService');
      final ByteData assetData = await rootBundle.load('assets/models/ggml-tiny.bin');
      await modelFile.writeAsBytes(assetData.buffer.asUint8List(), flush: true);
    }
    return modelFile.path;
  }

  // Notice: We now accept a List<double> from RAM, NOT a file path!
  Future<String> transcribe(List<double> audioFloats) async {
    if (!_initialized) await initialize();
    if (audioFloats.isEmpty || _isTranscribing) return "";

    _isTranscribing = true;
    String result = "";

    try {
      // FIX: Added the 'await' keyword here since FFI now uses Isolate.run()
      result = await _whisperFFI.transcribe(audioFloats);
    } catch (e) {
      dev.log("Native transcription error", name: 'WhisperService', error: e);
    } finally {
      _isTranscribing = false;
    }

    return result;
  }

  void dispose() {
    _whisperFFI.dispose();
    _initialized = false;
  }
}