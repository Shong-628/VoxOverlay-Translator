// whisper_service.dart
import 'dart:io';
import 'dart:isolate';
import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:whisper_ggml/whisper_ggml.dart';

class WhisperService {
  final WhisperController _whisperController = WhisperController();
  final WhisperModel _model = WhisperModel.tiny;
  bool _initialized = false;

  // Track files currently being processed to delete them if we force-stop
  final Set<String> _activeFiles = {};
  bool _isDisposed = false;

  Future<void> initialize() async {
    if (_initialized || _isDisposed) return;

    try {
      final modelPath = await _whisperController.getPath(_model);
      final modelFile = File(modelPath);

      // If the file isn't on the device yet, download it
      if (!await modelFile.exists()) {
        dev.log("Downloading Whisper model, this may take a moment...", name: 'WhisperService');
        await _whisperController.downloadModel(_model);
      }

      _initialized = true;
      dev.log("Whisper initialized successfully.", name: 'WhisperService');
    } catch (e) {
      dev.log("Failed to initialize or download Whisper model", name: 'WhisperService', error: e);
    }
  }

  Future<String> transcribe(String audioPath) async {
    if (!_initialized) await initialize();
    if (_isDisposed) return "";

    String? convertedWavPath;
    String transcriptionResult = "";

    _activeFiles.add(audioPath);

    try {
      String finalPath = audioPath;

      // 1. Handle PCM conversion in a BACKGROUND ISOLATE
      // This prevents the heavy byte manipulation from freezing the UI
      if (audioPath.endsWith('.pcm')) {
        convertedWavPath = await Isolate.run(() => _convertPcmToWav(audioPath));

        if (convertedWavPath != null) {
          _activeFiles.add(convertedWavPath);
          finalPath = convertedWavPath;
        }
      }

      if (_isDisposed) return "";

      // 2. Perform Transcription
      // We run this directly. Assuming whisper_ggml uses internal C++ async threads,
      // this shouldn't block the Dart main thread.
      final result = await _whisperController.transcribe(
        model: _model,
        audioPath: finalPath,
        lang: 'en',
      );

      transcriptionResult = result?.transcription.text ?? "";

    } catch (e) {
      dev.log("Whisper transcription error", name: 'WhisperService', error: e);
    } finally {
      // 3. Immediate Cleanup
      await _deleteFile(audioPath);
      _activeFiles.remove(audioPath);

      if (convertedWavPath != null) {
        await _deleteFile(convertedWavPath);
        _activeFiles.remove(convertedWavPath);
      }
    }

    return transcriptionResult;
  }

  Future<void> dispose() async {
    _isDisposed = true;
    dev.log("Disposing WhisperService, cleaning active files...", name: 'WhisperService');

    final filesToRemove = Set<String>.from(_activeFiles);
    for (var path in filesToRemove) {
      await _deleteFile(path);
    }
    _activeFiles.clear();
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        dev.log("Deleted temporary file: $path", name: 'WhisperService');
      }
    } catch (e) {
      // Ignore errors if file is already gone
    }
  }

  // --- STATIC METHODS ---
  // Making this static allows it to run inside Isolate.run() without
  // copying the entire WhisperService class (and its native pointers) into memory.
  static Future<String?> _convertPcmToWav(String pcmPath) async {
    try {
      final File pcmFile = File(pcmPath);
      final wavPath = pcmPath.replaceAll('.pcm', '.wav');

      if (!await pcmFile.exists()) return null;

      final Uint8List pcmBytes = await pcmFile.readAsBytes();

      const int sampleRate = 16000;
      const int channels = 1;
      const int bitDepth = 16;
      const int bytesPerSample = bitDepth ~/ 8;
      const int byteRate = sampleRate * channels * bytesPerSample;

      final ByteData header = ByteData(44);

      // RIFF header
      header.setUint8(0, 0x52); // 'R'
      header.setUint8(1, 0x49); // 'I'
      header.setUint8(2, 0x46); // 'F'
      header.setUint8(3, 0x46); // 'F'
      header.setUint32(4, 36 + pcmBytes.length, Endian.little);
      header.setUint8(8, 0x57); // 'W'
      header.setUint8(9, 0x41); // 'A'
      header.setUint8(10, 0x56); // 'V'
      header.setUint8(11, 0x45); // 'E'

      // fmt chunk
      header.setUint8(12, 0x66); // 'f'
      header.setUint8(13, 0x6D); // 'm'
      header.setUint8(14, 0x74); // 't'
      header.setUint8(15, 0x20); // ' '
      header.setUint32(16, 16, Endian.little);
      header.setUint16(20, 1, Endian.little);
      header.setUint16(22, channels, Endian.little);
      header.setUint32(24, sampleRate, Endian.little);
      header.setUint32(28, byteRate, Endian.little);
      header.setUint16(32, channels * bytesPerSample, Endian.little);
      header.setUint16(34, bitDepth, Endian.little);

      // data chunk
      header.setUint8(36, 0x64); // 'd'
      header.setUint8(37, 0x61); // 'a'
      header.setUint8(38, 0x74); // 't'
      header.setUint8(39, 0x61); // 'a'
      header.setUint32(40, pcmBytes.length, Endian.little);

      final File wavFile = File(wavPath);
      final Uint8List wavBytes = Uint8List(44 + pcmBytes.length);

      // Combine header and PCM data
      wavBytes.setAll(0, header.buffer.asUint8List());
      wavBytes.setAll(44, pcmBytes);

      await wavFile.writeAsBytes(wavBytes);
      return wavPath;
    } catch (e) {
      dev.log("PCM conversion failed", name: 'WhisperService', error: e);
      return null;
    }
  }
}