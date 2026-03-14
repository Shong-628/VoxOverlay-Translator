// widgets/test_whisper.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../services/whisper_service.dart';

class WhisperTestWidget extends StatefulWidget {
  const WhisperTestWidget({super.key});

  @override
  State<WhisperTestWidget> createState() => _WhisperTestWidgetState();
}

class _WhisperTestWidgetState extends State<WhisperTestWidget> {
  final AudioRecorder _recorder = AudioRecorder();
  final WhisperService _whisperService = WhisperService();

  StreamSubscription<Uint8List>? _audioStreamSubscription;

  // Buffers matching the AudioPipelineService logic
  final List<int> _byteBuffer = [];
  final List<double> _contextBuffer = [];

  // Configuration from AudioPipelineService
  static const int _sampleRate = 16000;
  static const int _minChunkBytes = 16000; // Trigger processing roughly every 0.5s
  static const int _maxContextSamples = _sampleRate * 12; // Max 12 seconds context

  // VAD / Silence Detection
  int _silenceChunks = 0;
  static const double _silenceThreshold = 0.01;
  static const int _maxSilenceChunks = 3;

  bool _isInitializing = true;
  bool _isRecording = false;
  bool _isProcessing = false;

  String _statusMessage = "Initializing Whisper Model...";
  final List<String> _transcripts = [];

  // Live stats for UI feedback
  double _currentRms = 0.0;
  bool _isSilent = false;

  @override
  void initState() {
    super.initState();
    _initWhisper();
  }

  Future<void> _initWhisper() async {
    try {
      await _whisperService.initialize();
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = "Ready to record";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = "Failed to init Whisper: $e";
        });
      }
    }
  }

  Future<void> _startTest() async {
    if (!await _recorder.hasPermission()) {
      setState(() => _statusMessage = "Microphone permission denied");
      return;
    }

    setState(() {
      _isRecording = true;
      _statusMessage = "Listening... (Streaming)";
      _transcripts.clear();
      _byteBuffer.clear();
      _contextBuffer.clear();
      _silenceChunks = 0;
      _currentRms = 0.0;
    });

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );

    _audioStreamSubscription = stream.listen((data) {
      _byteBuffer.addAll(data);
      // Trigger processing rapidly for real-time feel
      if (_byteBuffer.length >= _minChunkBytes && !_isProcessing) {
        _processAudioChunk();
      }
    });
  }

  Future<void> _processAudioChunk() async {
    if (!_isRecording || _byteBuffer.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Extract even number of bytes for 16-bit PCM conversion
      int bytesToTake = _byteBuffer.length - (_byteBuffer.length % 2);
      final chunkBytes = Uint8List.fromList(_byteBuffer.sublist(0, bytesToTake));
      _byteBuffer.removeRange(0, bytesToTake);

      // 2. Convert to Floats and calculate RMS
      final int16List = chunkBytes.buffer.asInt16List();
      final floatList = List<double>.filled(int16List.length, 0.0);
      double sumSquares = 0.0;

      for (int i = 0; i < int16List.length; i++) {
        double floatVal = int16List[i] / 32768.0;
        floatList[i] = floatVal;
        sumSquares += floatVal * floatVal;
      }

      double rms = math.sqrt(sumSquares / int16List.length);

      // 3. Handle Silence / VAD
      if (rms < _silenceThreshold) {
        _silenceChunks++;
      } else {
        _silenceChunks = 0;
      }

      setState(() {
        _currentRms = rms;
        _isSilent = _silenceChunks >= _maxSilenceChunks;
      });

      if (_silenceChunks >= _maxSilenceChunks) {
        if (_contextBuffer.isNotEmpty) {
          _contextBuffer.clear();
          // Insert a visual marker in the test UI so we know silence triggered a reset
          if (_transcripts.isEmpty || _transcripts.first != "--- Silence Detected: Context Cleared ---") {
            setState(() {
              _transcripts.insert(0, "--- Silence Detected: Context Cleared ---");
            });
          }
        }
        _isProcessing = false;
        return;
      }

      // 4. Update Context Window
      _contextBuffer.addAll(floatList);
      if (_contextBuffer.length > _maxContextSamples) {
        _contextBuffer.removeRange(0, _contextBuffer.length - _maxContextSamples);
      }

      // 5. Transcribe Context Window
      final transcript = await _whisperService.transcribe(Float32List.fromList(_contextBuffer));

      // 6. Filter and update UI
      final cleanTranscript = transcript.replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), '').trim();

      if (cleanTranscript.isNotEmpty && mounted) {
        setState(() {
          // If the last item was a real transcript (not a silence marker), replace it to simulate streaming updates.
          // Otherwise, insert new.
          if (_transcripts.isNotEmpty && !_transcripts.first.startsWith("---")) {
            _transcripts[0] = cleanTranscript;
          } else {
            _transcripts.insert(0, cleanTranscript);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Error during transcription: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        // Event loop catch-up
        if (_byteBuffer.length >= _minChunkBytes && _isRecording) {
          Future.microtask(() => _processAudioChunk());
        }
      }
    }
  }

  Future<void> _stopTest() async {
    setState(() {
      _isRecording = false;
      _statusMessage = "Stopping...";
    });

    await _audioStreamSubscription?.cancel();
    await _recorder.stop();
    _byteBuffer.clear();
    _contextBuffer.clear();

    if (mounted) {
      setState(() {
        _statusMessage = "Ready to record";
        _currentRms = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _audioStreamSubscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.record_voice_over, size: 20),
            SizedBox(width: 8),
            Text(
              "VAD & Stream Test",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        const Text(
          "Tests fast-chunking, RMS silence detection, and context windowing.",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // Live Debug Stats
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text("RMS: ${_currentRms.toStringAsFixed(4)}",
                  style: TextStyle(color: _currentRms < _silenceThreshold ? Colors.grey : Colors.green, fontWeight: FontWeight.bold)
              ),
              Text("Status: ${_isSilent ? 'SILENT' : 'VOCAL'}",
                  style: TextStyle(color: _isSilent ? Colors.grey : Colors.blue, fontWeight: FontWeight.bold)
              ),
              Text("Context: ${(_contextBuffer.length / _sampleRate).toStringAsFixed(1)}s"),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Transcripts Display Box
        Container(
          height: 200,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: _transcripts.isEmpty
              ? const Center(
            child: Text(
              "Streaming transcripts will appear here...",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          )
              : ListView.separated(
            itemCount: _transcripts.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final text = _transcripts[index];
              final isSystemMessage = text.startsWith("---");
              return Text(
                text,
                style: TextStyle(
                  fontWeight: isSystemMessage ? FontWeight.normal : FontWeight.w500,
                  fontStyle: isSystemMessage ? FontStyle.italic : FontStyle.normal,
                  color: isSystemMessage ? Colors.blueGrey : Colors.black87,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Status Message
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isInitializing || (_isProcessing && !_isSilent)) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              _statusMessage,
              style: TextStyle(
                color: _isRecording ? Colors.red : Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Action Button
        ElevatedButton.icon(
          onPressed: _isInitializing ? null : (_isRecording ? _stopTest : _startTest),
          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRecording ? Colors.red.shade100 : null,
            foregroundColor: _isRecording ? Colors.red.shade900 : null,
          ),
          label: Text(_isRecording ? "Stop Recording" : "Start Pipeline Test"),
        ),
      ],
    );
  }
}