// home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/audio_pipeline_service.dart';
import '../overlay/overlay_service.dart';
import 'settings_screen.dart';
import 'onboarding_screen.dart';

import '../widgets/mic_input_visualizer.dart';
import '../widgets/test_translate.dart';
import '../widgets/test_whisper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // LOCK STATE: Prevents spam clicking
  bool _isToggling = false;

  Future<void> _handleTogglePipeline(AudioPipelineService service) async {
    // 1. If we are already processing a click, ignore any new clicks entirely.
    if (_isToggling) return;

    // 2. Lock the UI
    setState(() {
      _isToggling = true;
    });

    try {
      if (!service.isRunning) {
        // 1. Check Overlay Permission
        bool hasOverlayPermission = await OverlayService.hasPermission();
        if (!hasOverlayPermission) {
          await OverlayService.requestPermission();
          hasOverlayPermission = await OverlayService.hasPermission();
        }

        if (!hasOverlayPermission) {
          if (!mounted) return; // Safety check after await
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Overlay permission is required")),
          );
          return;
        }

        // 2. Check Microphone Permission safely
        var micStatus = await Permission.microphone.status;

        if (micStatus.isPermanentlyDenied) {
          if (!mounted) return;
          _showSettingsDialog("Microphone access is permanently denied. Please enable it in system settings.");
          return;
        }

        if (!micStatus.isGranted) {
          micStatus = await Permission.microphone.request();
        }

        if (micStatus.isGranted) {
          await OverlayService.startOverlay();
          debugPrint("Home: Starting Overlay");
          await service.startPipeline();
          debugPrint("Home: Starting Pipeline");
        } else {
          if (!mounted) return; // Safety check after await

          // Catch the scenario where they just denied it during the request
          if (micStatus.isPermanentlyDenied) {
            _showSettingsDialog("Microphone access is permanently denied. Please enable it in system settings.");
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Microphone permission is required for transcription")),
            );
          }
        }
      } else {
        // Stopping
        await service.stopPipeline();
        await OverlayService.stopOverlay();
        debugPrint("Home: Stopping Pipeline");
      }
    } catch (e) {
      debugPrint("Error toggling pipeline: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred: $e")),
        );
      }
    } finally {
      // 3. Always unlock the UI when done, whether it succeeded or failed
      if (mounted) {
        setState(() {
          _isToggling = false;
        });
      }
    }
  }

  // Helper method to direct users to app settings
  void _showSettingsDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Permission Required"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings(); // Requires permission_handler
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pipeline = context.watch<AudioPipelineService>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("VoxOverlay"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: colorScheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    "VoxOverlay",
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Real-time Translator",
                    style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Home"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text("View Tutorial"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Settings"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const Divider(),
            const AboutListTile(
              icon: Icon(Icons.info_outline),
              applicationName: "VoxOverlay Translator",
              applicationVersion: "1.0.0",
              child: Text("About App"),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Status Indicator
              _StatusCard(
                isRunning: pipeline.isRunning,
                isPaused: pipeline.isPaused,
              ),

              const SizedBox(height: 60),

              // Main Action Button
              _StartStopButton(
                isRunning: pipeline.isRunning,
                isPaused: pipeline.isPaused,
                isLoading: _isToggling, // Pass the lock state
                onPressed: () => _handleTogglePipeline(pipeline),
              ),

              const SizedBox(height: 40),

              Text(
                pipeline.isRunning
                    ? "Translation is active.\nCheck the overlay for subtitles."
                    : "Ready to translate.\nTap the button to start.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface.withAlpha(153),
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 40),

              // Mic Test Visualizer Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                  ),
                ),
                child: const Column(
                  children: [
                    MicInputVisualizer(),
                    SizedBox(height: 10),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Translation Test Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                  ),
                ),
                child: const Column(
                  children: [
                    TranslationTestWidget(),
                    SizedBox(height: 10),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Whisper Transcription Test Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                  ),
                ),
                child: const Column(
                  children: [
                    WhisperTestWidget(),
                    SizedBox(height: 10),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool isRunning;
  final bool isPaused;

  const _StatusCard({required this.isRunning, required this.isPaused});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Determine the state colors and text
    Color statusColor;
    String statusText;

    if (!isRunning) {
      statusColor = colorScheme.onSurfaceVariant;
      statusText = "SERVICE STOPPED";
    } else if (isPaused) {
      statusColor = Colors.orange;
      statusText = "SERVICE PAUSED";
    } else {
      statusColor = Colors.green;
      statusText = "SERVICE RUNNING";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isRunning
            ? (isPaused ? Colors.orange.withAlpha(50) : colorScheme.primaryContainer.withAlpha(76))
            : colorScheme.surfaceContainerHighest.withAlpha(76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRunning ? statusColor : colorScheme.outline,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: isRunning ? [
                BoxShadow(
                  color: statusColor.withAlpha(127),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ] : [],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            statusText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: isRunning ? statusColor : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartStopButton extends StatelessWidget {
  final bool isRunning;
  final bool isPaused;
  final bool isLoading;
  final VoidCallback onPressed;

  const _StartStopButton({
    required this.isRunning,
    required this.isPaused,
    required this.isLoading,
    required this.onPressed
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // If running but paused, show an orange/amber theme. Otherwise red for Stop, primary for Start.
    Color buttonColor = !isRunning
        ? colorScheme.primaryContainer
        : (isPaused ? Colors.orange.shade200 : colorScheme.errorContainer);

    Color iconColor = !isRunning
        ? colorScheme.onPrimaryContainer
        : (isPaused ? Colors.orange.shade900 : colorScheme.onErrorContainer);

    // Give visual feedback when disabled
    if (isLoading) {
      buttonColor = buttonColor.withAlpha(128);
      iconColor = iconColor.withAlpha(128);
    }

    return GestureDetector(
      // Disable tap if it's currently loading
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: buttonColor,
          boxShadow: [
            BoxShadow(
              color: buttonColor.withAlpha(150),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: iconColor,
                  strokeWidth: 4,
                ),
              )
            else ...[
              Icon(
                !isRunning ? Icons.play_arrow_rounded : Icons.stop_rounded,
                size: 80,
                color: iconColor,
              ),
              Text(
                !isRunning ? "START" : "STOP",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}