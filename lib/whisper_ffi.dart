// lib/whisper_ffi.dart
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// --- FFI Type Definitions ---
typedef BridgeWhisperInitC = Pointer<Void> Function(Pointer<Utf8> modelPath);
typedef BridgeWhisperInitDart = Pointer<Void> Function(Pointer<Utf8> modelPath);

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

  // Added language parameter
  Future<String> transcribe(Float32List audioData, {String language = 'auto'}) async {
    if (_context == null || _context!.address == 0) return "";

    // 1. Grab the raw memory address of the C++ context.
    // Integers can be safely passed across isolates!
    final int contextAddress = _context!.address;

    // 2. Offload the heavy execution to a background isolate
    return await Isolate.run(() {
      // Re-open the library inside the new isolate
      final lib = Platform.isAndroid
          ? DynamicLibrary.open('libwhisper_native.so')
          : DynamicLibrary.process();

      final transcribeFunc = lib.lookupFunction<BridgeWhisperTranscribeC, BridgeWhisperTranscribeDart>('bridge_whisper_transcribe');
      final freeStringFunc = lib.lookupFunction<BridgeWhisperFreeStringC, BridgeWhisperFreeStringDart>('bridge_whisper_free_string');

      // Reconstruct the C++ context pointer from the memory address
      final isolateContext = Pointer<Void>.fromAddress(contextAddress);

      // Allocate native memory
      final Pointer<Float> audioPtr = malloc.allocate<Float>(audioData.length * sizeOf<Float>());
      final Pointer<Utf8> langPtr = language.toNativeUtf8();

      audioPtr.asTypedList(audioData.length).setAll(0, audioData);

      // 3. Run inference. THIS is the blocking call.
      // Because we are in Isolate.run(), it blocks this background thread, NOT the UI!
      final Pointer<Utf8> resultPtr = transcribeFunc(isolateContext, audioPtr, audioData.length, langPtr);

      String text = "";
      if (resultPtr != nullptr) {
        text = resultPtr.toDartString();
        freeStringFunc(resultPtr);
      }

      // Clean up memory
      malloc.free(audioPtr);
      malloc.free(langPtr);

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