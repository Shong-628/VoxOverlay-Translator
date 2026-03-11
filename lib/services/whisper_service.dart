import 'dart:io';
import 'dart:developer' as dev; // Import the developer log
import 'package:flutter/services.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

class WhisperService {
  final WhisperController _whisperController = WhisperController();
  final WhisperModel _model = WhisperModel.base;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final modelPath = await _whisperController.getPath(_model);
      final modelFile = File(modelPath);

      if (!await modelFile.exists()) {
        final data = await rootBundle.load('assets/ggml-${_model.modelName}.bin');
        await modelFile.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      }

      _initialized = true;
    } catch (e, stackTrace) {
      dev.log(
          "Asset load failed, attempting download",
          name: 'WhisperService',
          error: e,
          stackTrace: stackTrace
      );
      await _whisperController.downloadModel(_model);
      _initialized = true;
    }
  }

  Future<String> transcribe(String audioPath) async {
    if (!_initialized) await initialize();

    try {
      final result = await _whisperController.transcribe(
        model: _model,
        audioPath: audioPath,
        lang: 'en',
      );

      return result?.transcription.text ?? "";
    } catch (e, stackTrace) {
      dev.log(
          "Whisper transcription error",
          name: 'WhisperService',
          error: e,
          stackTrace: stackTrace
      );
      return "";
    }
  }
}