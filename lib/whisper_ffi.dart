// lib/whisper_ffi.dart
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data'; // Added for Float32List
import 'package:ffi/ffi.dart';

// --- FFI Type Definitions ---
typedef BridgeWhisperInitC = Pointer<Void> Function(Pointer<Utf8> modelPath);
typedef BridgeWhisperInitDart = Pointer<Void> Function(Pointer<Utf8> modelPath);

typedef BridgeWhisperTranscribeC = Pointer<Utf8> Function(Pointer<Void> ctx, Pointer<Float> pcmf32, Int32 n_samples);
typedef BridgeWhisperTranscribeDart = Pointer<Utf8> Function(Pointer<Void> ctx, Pointer<Float> pcmf32, int n_samples);

typedef BridgeWhisperFreeC = Void Function(Pointer<Void> ctx);
typedef BridgeWhisperFreeDart = void Function(Pointer<Void> ctx);

class WhisperFFI {
  late DynamicLibrary _lib;
  late BridgeWhisperInitDart _initModel;
  late BridgeWhisperFreeDart _freeModel;

  Pointer<Void>? _context;

  WhisperFFI() {
    _lib = Platform.isAndroid ? DynamicLibrary.open('libwhisper_native.so') : DynamicLibrary.process();

    _initModel = _lib.lookupFunction<BridgeWhisperInitC, BridgeWhisperInitDart>('bridge_whisper_init');
    _freeModel = _lib.lookupFunction<BridgeWhisperFreeC, BridgeWhisperFreeDart>('bridge_whisper_free');
  }

  bool init(String modelPath) {
    if (_context != null && _context!.address != 0) return true;

    final pathPtr = modelPath.toNativeUtf8();
    _context = _initModel(pathPtr);

    malloc.free(pathPtr);
    return _context != null && _context!.address != 0;
  }

  // Updated to Float32List to match the WhisperService optimization
  Future<String> transcribe(Float32List audioData) async {
    if (_context == null || _context!.address == 0) return "";

    final int contextAddress = _context!.address;

    return await Isolate.run(() {
      final lib = Platform.isAndroid
          ? DynamicLibrary.open('libwhisper_native.so')
          : DynamicLibrary.process();

      final transcribeFunc = lib.lookupFunction<BridgeWhisperTranscribeC, BridgeWhisperTranscribeDart>('bridge_whisper_transcribe');

      final isolateContext = Pointer<Void>.fromAddress(contextAddress);

      // 1. Allocate native memory
      final Pointer<Float> audioPtr = malloc.allocate<Float>(audioData.length * sizeOf<Float>());

      // 2. FAST COPY: Map native memory to Dart and copy instantly (No for-loop required)
      audioPtr.asTypedList(audioData.length).setAll(0, audioData);

      // 3. Run inference
      final Pointer<Utf8> resultPtr = transcribeFunc(isolateContext, audioPtr, audioData.length);
      final String text = resultPtr.toDartString();

      // 4. Memory Cleanup
      malloc.free(audioPtr);

      return text.trim();
    });
  }

  void dispose() {
    if (_context != null && _context!.address != 0) {
      _freeModel(_context!);
      _context = null;
    }
  }
}