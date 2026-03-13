// lib/whisper_ffi.dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef BridgeWhisperInitC = Pointer<Void> Function(Pointer<Utf8> modelPath);
typedef BridgeWhisperInitDart = Pointer<Void> Function(Pointer<Utf8> modelPath);

typedef BridgeWhisperTranscribeC = Pointer<Utf8> Function(Pointer<Void> ctx, Pointer<Float> pcmf32, Int32 n_samples);
typedef BridgeWhisperTranscribeDart = Pointer<Utf8> Function(Pointer<Void> ctx, Pointer<Float> pcmf32, int n_samples);

typedef BridgeWhisperFreeC = Void Function(Pointer<Void> ctx);
typedef BridgeWhisperFreeDart = void Function(Pointer<Void> ctx);

class WhisperFFI {
  late DynamicLibrary _lib;
  late BridgeWhisperInitDart _initModel;
  late BridgeWhisperTranscribeDart _transcribe;
  late BridgeWhisperFreeDart _freeModel;

  // FIX 2: Explicitly typing the Pointer
  Pointer<Void>? _context;

  WhisperFFI() {
    _lib = Platform.isAndroid ? DynamicLibrary.open('libwhisper_native.so') : DynamicLibrary.process();

    _initModel = _lib.lookupFunction<BridgeWhisperInitC, BridgeWhisperInitDart>('bridge_whisper_init');
    _transcribe = _lib.lookupFunction<BridgeWhisperTranscribeC, BridgeWhisperTranscribeDart>('bridge_whisper_transcribe');
    _freeModel = _lib.lookupFunction<BridgeWhisperFreeC, BridgeWhisperFreeDart>('bridge_whisper_free');
  }

  bool init(String modelPath) {
    if (_context != null) return true;
    final pathPtr = modelPath.toNativeUtf8();
    _context = _initModel(pathPtr);
    malloc.free(pathPtr);

    // FIX 3: Safe address checking instead of nullptr
    return _context != null && _context!.address != 0;
  }

  String transcribe(List<double> audioData) {
    if (_context == null || _context!.address == 0) return "";

    final Pointer<Float> audioPtr = malloc.allocate<Float>(audioData.length * sizeOf<Float>());
    for (int i = 0; i < audioData.length; i++) {
      audioPtr[i] = audioData[i];
    }

    final Pointer<Utf8> resultPtr = _transcribe(_context!, audioPtr, audioData.length);
    final String result = resultPtr.toDartString();

    malloc.free(audioPtr);
    return result.trim();
  }

  void dispose() {
    if (_context != null && _context!.address != 0) {
      _freeModel(_context!);
      _context = null;
    }
  }
}