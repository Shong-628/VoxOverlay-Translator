// lib/whisper_ffi.dart
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// --- FFI Type Definitions ---
typedef BridgeWhisperInitC = Pointer<Void> Function(Pointer<Utf8> modelPath);
typedef BridgeWhisperInitDart = Pointer<Void> Function(Pointer<Utf8> modelPath);

// NEW: Added Pointer<Utf8> language parameter to both signatures
typedef BridgeWhisperTranscribeC = Pointer<Utf8> Function(Pointer<Void> ctx, Pointer<Float> pcmf32, Int32 n_samples, Pointer<Utf8> language);
typedef BridgeWhisperTranscribeDart = Pointer<Utf8> Function(Pointer<Void> ctx, Pointer<Float> pcmf32, int n_samples, Pointer<Utf8> language);

// Definitions for freeing the string
typedef BridgeWhisperFreeStringC = Void Function(Pointer<Utf8> str);
typedef BridgeWhisperFreeStringDart = void Function(Pointer<Utf8> str);

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

  // NEW: Added language parameter
  Future<String> transcribe(Float32List audioData, {String language = 'auto'}) async {
    if (_context == null || _context!.address == 0) return "";

    final int contextAddress = _context!.address;

    return await Isolate.run(() {
      final lib = Platform.isAndroid
          ? DynamicLibrary.open('libwhisper_native.so')
          : DynamicLibrary.process();

      final transcribeFunc = lib.lookupFunction<BridgeWhisperTranscribeC, BridgeWhisperTranscribeDart>('bridge_whisper_transcribe');
      final freeStringFunc = lib.lookupFunction<BridgeWhisperFreeStringC, BridgeWhisperFreeStringDart>('bridge_whisper_free_string');

      final isolateContext = Pointer<Void>.fromAddress(contextAddress);

      // 1. Allocate native memory for audio and language string
      final Pointer<Float> audioPtr = malloc.allocate<Float>(audioData.length * sizeOf<Float>());
      final Pointer<Utf8> langPtr = language.toNativeUtf8(); // NEW: Convert Dart string to C string

      // 2. Map native memory to Dart and copy
      audioPtr.asTypedList(audioData.length).setAll(0, audioData);

      // 3. Run inference (NEW: Pass langPtr)
      final Pointer<Utf8> resultPtr = transcribeFunc(isolateContext, audioPtr, audioData.length, langPtr);

      String text = "";
      if (resultPtr != nullptr) {
        text = resultPtr.toDartString();
        freeStringFunc(resultPtr);
      }

      // 4. Clean up memory
      malloc.free(audioPtr);
      malloc.free(langPtr); // NEW: Free language string memory

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