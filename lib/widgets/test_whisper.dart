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
  // Dependencies
  final AudioRecorder _recorder = AudioRecorder();
  final WhisperService _whisperService = WhisperService();
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  // Audio Buffers
  final List<int> _byteBuffer = [];
  final List<double> _contextBuffer = [];

  // Audio Pipeline Configuration
  static const int _sampleRate = 16000;
  static const int _minChunkBytes = 16000; // ~0.5 seconds of 16-bit PCM
  static const int _maxContextSamples = _sampleRate * 12; // 12 seconds rolling window

  // VAD (Voice Activity Detection) Settings
  // Note: Threshold lowered and max silence increased to prevent premature cut-offs
  static const double _silenceThreshold = 0.002;
  static const int _maxSilenceChunks = 6; // ~3 seconds of silence before flushing
  int _silenceChunks = 0;

  // State Management
  bool _isInitializing = true;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isSilent = false;
  bool _isNewSentence = true;

  // UI State
  String _statusMessage = "Initializing Whisper Model...";
  final List<String> _transcripts = [];
  double _currentRms = 0.0;

  @override
  void initState() {
    super.initState();
    _initWhisper();
  }

  @override
  void dispose() {
    _audioStreamSubscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ==========================================
  // CORE LIFECYCLE LOGIC
  // ==========================================

  Future<void> _initWhisper() async {
    try {
      await _whisperService.initialize();
      _updateState(() {
        _isInitializing = false;
        _statusMessage = "Ready to record";
      });
    } catch (e) {
      _updateState(() {
        _isInitializing = false;
        _statusMessage = "Failed to init Whisper: $e";
      });
    }
  }

  Future<void> _startTest() async {
    if (!await _recorder.hasPermission()) {
      _updateState(() => _statusMessage = "Microphone permission denied");
      return;
    }

    _resetStateForRecording();

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );

    _audioStreamSubscription = stream.listen(_onAudioDataReceived);
  }

  Future<void> _stopTest() async {
    _updateState(() {
      _isRecording = false;
      _statusMessage = "Stopping...";
    });

    await _audioStreamSubscription?.cancel();
    await _recorder.stop();

    _byteBuffer.clear();
    _contextBuffer.clear();
    _isProcessing = false;

    _updateState(() {
      _statusMessage = "Ready to record";
      _currentRms = 0.0;
    });
  }

  // ==========================================
  // AUDIO PROCESSING PIPELINE
  // ==========================================

  void _onAudioDataReceived(Uint8List data) {
    _byteBuffer.addAll(data);

    // Process chunk only if buffer has enough data and isn't currently locked
    if (_byteBuffer.length >= _minChunkBytes && !_isProcessing) {
      _processAudioChunk();
    }
  }

  Future<void> _processAudioChunk() async {
    if (!_isRecording || _byteBuffer.isEmpty || _isProcessing) return;

    _isProcessing = true;

    try {
      // 1. Extract raw bytes safely (ensure even number for 16-bit PCM)
      final chunkBytes = _extractChunkBytes();

      // 2. Convert PCM to Floats for Whisper and calculate volume (RMS)
      final floatList = _convertPcm16ToFloat32(chunkBytes);
      final rms = _calculateRms(floatList);

      // 3. Handle Voice Activity Detection (VAD)
      _updateVadState(rms);

      // 4. If silent for too long, flush context to save processing power
      if (_isSilent) {
        await _handleSilence();
        return;
      }

      // 5. Update Context Window (User is speaking)
      _updateContextWindow(floatList);

      // 6. Transcribe the current audio context
      final transcript = await _whisperService.transcribe(Float32List.fromList(_contextBuffer));

      // 7. Filter hallucinated system tags (e.g., [Silence], (music))
      final cleanTranscript = transcript.replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), '').trim();

      // 8. Update the UI with the text
      _updateTranscriptUI(cleanTranscript);

    } catch (e) {
      debugPrint("Diagnostic Test Error: $e");
      _updateState(() => _statusMessage = "Error: $e");
    } finally {
      _isProcessing = false;
      _catchUpEventLoop();
    }
  }

  // ==========================================
  // HELPER METHODS (MATH & DATA MANIPULATION)
  // ==========================================

  Uint8List _extractChunkBytes() {
    int bytesToTake = _byteBuffer.length - (_byteBuffer.length % 2);
    final chunkBytes = Uint8List.fromList(_byteBuffer.sublist(0, bytesToTake));
    _byteBuffer.removeRange(0, bytesToTake);
    return chunkBytes;
  }

  List<double> _convertPcm16ToFloat32(Uint8List chunkBytes) {
    // Using ByteData avoids memory alignment exceptions and endianness distortion
    final floatList = <double>[];
    final byteData = ByteData.sublistView(chunkBytes);

    // Normalize 16-bit PCM (-32768 to 32767) to Float32 (-1.0 to 1.0)
    for (int i = 0; i < chunkBytes.length; i += 2) {
      final int16Sample = byteData.getInt16(i, Endian.little);
      floatList.add(int16Sample / 32768.0);
    }
    return floatList;
  }

  double _calculateRms(List<double> floatList) {
    if (floatList.isEmpty) return 0.0;
    double sumSquares = floatList.fold(0.0, (sum, value) => sum + (value * value));
    return math.sqrt(sumSquares / floatList.length);
  }

  void _updateVadState(double rms) {
    if (rms < _silenceThreshold) {
      _silenceChunks++;
    } else {
      _silenceChunks = 0;
    }

    _updateState(() {
      _currentRms = rms;
      _isSilent = _silenceChunks >= _maxSilenceChunks;
    });
  }

  Future<void> _handleSilence() async {
    if (_contextBuffer.isNotEmpty) {
      // 1. Do one final transcription of the complete sentence
      final finalTranscript = await _whisperService.transcribe(Float32List.fromList(_contextBuffer));
      final cleanTranscript = finalTranscript.replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), '').trim();
      _updateTranscriptUI(cleanTranscript);

      // 2. Now clear the buffer
      _contextBuffer.clear();
      _isNewSentence = true;
    }
    _isProcessing = false;
  }

  void _updateContextWindow(List<double> newAudio) {
    _contextBuffer.addAll(newAudio);
    // Keep window size bounded to prevent memory overflow
    if (_contextBuffer.length > _maxContextSamples) {
      _contextBuffer.removeRange(0, _contextBuffer.length - _maxContextSamples);
    }
  }

  void _updateTranscriptUI(String text) {
    if (text.isEmpty) return;

    _updateState(() {
      if (_isNewSentence || _transcripts.isEmpty) {
        _transcripts.insert(0, text);
        _isNewSentence = false;
      } else {
        _transcripts[0] = text; // Update current sentence (Streaming effect)
      }
    });
  }

  void _catchUpEventLoop() {
    // If bytes piled up while Whisper was working, schedule an immediate re-run
    if (_byteBuffer.length >= _minChunkBytes && _isRecording) {
      Future.microtask(() => _processAudioChunk());
    }
  }

  void _resetStateForRecording() {
    _updateState(() {
      _isRecording = true;
      _statusMessage = "Listening... (Streaming)";
      _transcripts.clear();
      _byteBuffer.clear();
      _contextBuffer.clear();
      _silenceChunks = 0;
      _currentRms = 0.0;
      _isNewSentence = true;
    });
  }

  /// Helper to safely call setState only if the widget is still mounted
  void _updateState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0), // Added slight padding
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildLiveDebugStats(),
          const SizedBox(height: 16),
          _buildTranscriptsBox(),
          const SizedBox(height: 16),
          _buildStatusIndicator(),
          const SizedBox(height: 20),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.monitor_heart, size: 24, color: Colors.deepPurple),
        SizedBox(width: 8),
        // Wrapped in Flexible to prevent text overflow on small screens
        Flexible(
          child: Text(
            "Whisper Diagnostic Test",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveDebugStats() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text("RMS Vol: ${_currentRms.toStringAsFixed(4)}",
                    style: TextStyle(
                        color: _currentRms < _silenceThreshold ? Colors.grey : Colors.green,
                        fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text("VAD: ${_isSilent ? 'SILENCE' : 'VOICE'}",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: _isSilent ? Colors.grey : Colors.blue,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text("Byte Buffer: ${_byteBuffer.length}")),
              Expanded(
                child: Text(
                  "Context Window: ${(_contextBuffer.length / _sampleRate).toStringAsFixed(1)}s",
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptsBox() {
    return Container(
      height: 250,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
      ),
      child: _transcripts.isEmpty
          ? Center(
        child: Text(
          _isRecording ? "Speak into the microphone..." : "Waiting to start...",
          style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      )
          : ListView.separated(
        itemCount: _transcripts.length,
        separatorBuilder: (_, __) => const Divider(height: 16),
        itemBuilder: (context, index) {
          final isLatest = index == 0;
          return Text(
            _transcripts[index],
            style: TextStyle(
              fontSize: 16,
              fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
              color: isLatest ? Colors.black87 : Colors.black54,
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isInitializing || _isProcessing) ...[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
        ],
        // Wrapped in Flexible to prevent long error messages from breaking layout
        Flexible(
          child: Text(
            _statusMessage,
            style: TextStyle(
              color: _isRecording ? Colors.red : Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return ElevatedButton.icon(
      onPressed: _isInitializing ? null : (_isRecording ? _stopTest : _startTest),
      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isRecording ? Colors.red.shade100 : Colors.deepPurple.shade50,
        foregroundColor: _isRecording ? Colors.red.shade900 : Colors.deepPurple,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      label: Text(_isRecording ? "Stop Recording" : "Start Diagnostic"),
    );
  }
}