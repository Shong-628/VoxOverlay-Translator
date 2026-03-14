// lib/whisper_service.dart
import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../whisper_ffi.dart';

class WhisperService {
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal();

  final WhisperFFI _whisperFFI = WhisperFFI();

  bool _initialized = false;
  Future<void>? _initFuture;
  bool _isTranscribing = false;

  /// Safe, concurrent-proof initialization
  Future<void> initialize() {
    if (_initialized) return Future.value();

    // If an initialization is already running, wait for it instead of skipping
    _initFuture ??= _performInitialization();
    return _initFuture!;
  }

  Future<void> _performInitialization() async {
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
      // Clear the future so we can retry if it failed
      _initFuture = null;
    }
  }

  Future<String> _ensureModelIsReady() async {
    final docDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${docDir.path}/ggml-tiny.bin');

    // Quick size check to ensure the file isn't corrupted or partially written
    if (!await modelFile.exists() || await modelFile.length() < 5 * 1024 * 1024) {
      dev.log("Copying Whisper model to local storage...", name: 'WhisperService');
      final ByteData assetData = await rootBundle.load('assets/models/ggml-tiny.bin');
      await modelFile.writeAsBytes(assetData.buffer.asUint8List(), flush: true);
    }
    return modelFile.path;
  }

  /// Takes a typed Float32List for faster FFI memory mapping
  Future<String> transcribe(Float32List audioFloats) async {
    if (!_initialized) await initialize();

    // Fail fast if empty or locked
    if (audioFloats.isEmpty || _isTranscribing) return "";

    _isTranscribing = true;
    String result = "";

    try {
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