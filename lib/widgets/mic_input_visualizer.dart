// widgets/mic_input_visualizer.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

class MicInputVisualizer extends StatefulWidget {
  const MicInputVisualizer({super.key});

  @override
  State<MicInputVisualizer> createState() => _MicInputVisualizerState();
}

class _MicInputVisualizerState extends State<MicInputVisualizer> {
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _subscription;

  double _amplitude = 0.0;

  bool _hasInput = false;
  bool _isTesting = false;

  DateTime _lastInputTime = DateTime.now();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _start() async {
    var status = await Permission.microphone.request();
    if (!status.isGranted) return;

    _noiseMeter = NoiseMeter();

    setState(() {
      _isTesting = true;
    });

    _subscription = _noiseMeter!.noise.listen(
          (reading) {
        setState(() {
          _amplitude = reading.meanDecibel;

          // Detect input
          if (_amplitude > 35) {
            _hasInput = true;
            _lastInputTime = DateTime.now();
          } else {
            // If silent for >2 seconds
            if (DateTime.now().difference(_lastInputTime).inSeconds > 2) {
              _hasInput = false;
            }
          }
        });
      },
      onError: (err) {
        debugPrint(err.toString());
      },
    );
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    _subscription = null;

    setState(() {
      _isTesting = false;
      _hasInput = false;
      _amplitude = 0.0;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  double normalize(double db) {
    if (db < 30) return 0;
    if (db > 120) return 1;
    return (db - 30) / 90;
  }

  @override
  Widget build(BuildContext context) {
    final level = normalize(_amplitude);

    return Column(
      children: [

        const Text(
          "Microphone Test",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 4),

        const Text(
          "Speak into the microphone to verify input detection",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(20, (i) {
              double barHeight = (i / 20) < level ? 40 : 8;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: barHeight,
                decoration: BoxDecoration(
                  color: _hasInput ? Colors.greenAccent : Colors.redAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 10),

        Text(
          _hasInput
              ? "✓ Microphone input detected"
              : "⚠ No microphone input detected",
          style: TextStyle(
            color: _hasInput ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: _isTesting ? _stop : _start,
          icon: Icon(_isTesting ? Icons.stop : Icons.mic),
          label: Text(_isTesting ? "Stop Test" : "Test Microphone"),
        ),
      ],
    );
  }
}

// import '../widgets/mic_input_visualizer.dart';
// Example usage:
// Column(
// mainAxisAlignment: MainAxisAlignment.center,
// children: const [
//
// MicInputVisualizer(),
//
// SizedBox(height: 20),
//
// Icon(
// Icons.mic,
// size: 40,
// ),
//
// ],
// )