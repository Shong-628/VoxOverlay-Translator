// lib/services/whisper_service.dart

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../whisper_ffi.dart';

/// A Singleton service managing the native Whisper C++ bindings.
class WhisperService {
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal();

  final WhisperFFI _whisperFFI = WhisperFFI();

  bool _initialized = false;
  Future<void>? _initFuture;
  bool _isTranscribing = false;

  /// Initializes the Whisper model safely.
  /// Prevents concurrent initializations via `_initFuture`.
  Future<void> initialize() {
    if (_initialized) return Future.value();

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
        throw Exception("Whisper FFI returned a null context. Check model integrity.");
      }
    } catch (e) {
      dev.log("Failed to init native Whisper", name: 'WhisperService', error: e);
      rethrow; // Allow the UI to catch and display the error
    } finally {
      // Clear the future so we can retry initialization if it failed
      _initFuture = null;
    }
  }

  /// Copies the model from the bundle assets to the device's local filesystem.
  /// C++ standard libraries (used by whisper.cpp) cannot read directly from Android/iOS asset bundles.
  Future<String> _ensureModelIsReady() async {
    final docDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${docDir.path}/ggml-tiny.bin');

    // Quick size check to ensure the file isn't corrupted or partially written
    // (Assuming the tiny model is > 5MB. Adjust if using quantization).
    if (!await modelFile.exists() || await modelFile.length() < 5 * 1024 * 1024) {
      dev.log("Copying Whisper model to local storage...", name: 'WhisperService');
      final ByteData assetData = await rootBundle.load('assets/models/ggml-tiny.bin');
      await modelFile.writeAsBytes(assetData.buffer.asUint8List(), flush: true);
    }

    return modelFile.path;
  }

  /// Transcribes a raw Float32List containing 16kHz PCM audio data.
  /// Locks concurrently to prevent C++ segmentation faults.
  /// NEW: Added optional language parameter (defaults to auto-detect).
  Future<String> transcribe(Float32List audioFloats, {String language = 'auto'}) async {
    if (!_initialized) await initialize();

    // Fail fast if empty or currently locked by another transcription request
    if (audioFloats.isEmpty || _isTranscribing) return "";

    _isTranscribing = true;
    String result = "";

    try {
      // NEW: Pass the language down to the FFI layer.
      // NOTE: Ensure your WhisperFFI wrapper actually accepts and uses this parameter!
      result = await _whisperFFI.transcribe(audioFloats, language: language);
    } catch (e) {
      dev.log("Native transcription error", name: 'WhisperService', error: e);
    } finally {
      _isTranscribing = false;
    }

    return result;
  }

  /// Cleans up native C++ memory
  void dispose() {
    _whisperFFI.dispose();
    _initialized = false;
  }
}