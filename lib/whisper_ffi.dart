// lib/whisper_ffi.dart
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
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
    // Load the compiled C++ library
    _lib = Platform.isAndroid ? DynamicLibrary.open('libwhisper_native.so') : DynamicLibrary.process();

    // Lookup init and free functions for the main thread
    _initModel = _lib.lookupFunction<BridgeWhisperInitC, BridgeWhisperInitDart>('bridge_whisper_init');
    _freeModel = _lib.lookupFunction<BridgeWhisperFreeC, BridgeWhisperFreeDart>('bridge_whisper_free');
  }

  bool init(String modelPath) {
    if (_context != null && _context!.address != 0) return true;

    final pathPtr = modelPath.toNativeUtf8();
    _context = _initModel(pathPtr);

    // Always free memory allocated in Dart for C++
    malloc.free(pathPtr);

    // Safe address checking instead of nullptr
    return _context != null && _context!.address != 0;
  }

  // Notice this is now a Future<String> to handle the background isolate
  Future<String> transcribe(List<double> audioData) async {
    if (_context == null || _context!.address == 0) return "";

    // Extract the raw memory address so we can pass it across the isolate boundary
    final int contextAddress = _context!.address;

    // Run the heavy C++ transcription in a background thread to prevent UI freezing
    return await Isolate.run(() {
      // 1. Reopen the library inside the isolate (Isolates don't share memory/objects)
      final lib = Platform.isAndroid
          ? DynamicLibrary.open('libwhisper_native.so')
          : DynamicLibrary.process();

      final transcribeFunc = lib.lookupFunction<BridgeWhisperTranscribeC, BridgeWhisperTranscribeDart>('bridge_whisper_transcribe');

      // 2. Reconstruct the C++ context pointer from the integer memory address
      final isolateContext = Pointer<Void>.fromAddress(contextAddress);

      // 3. Allocate memory in C for the audio float array
      final Pointer<Float> audioPtr = malloc.allocate<Float>(audioData.length * sizeOf<Float>());
      for (int i = 0; i < audioData.length; i++) {
        audioPtr[i] = audioData[i];
      }

      // 4. Run the C++ code (This blocks the isolate, NOT the main UI thread)
      final Pointer<Utf8> resultPtr = transcribeFunc(isolateContext, audioPtr, audioData.length);
      final String text = resultPtr.toDartString();

      // 5. Cleanup the audio memory to prevent RAM leaks
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