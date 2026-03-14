// home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/audio_pipeline_service.dart';
import '../overlay/overlay_service.dart';
import 'settings_screen.dart';
import 'onboarding_screen.dart';

import '../widgets/mic_input_visualizer.dart';
// Testing widgets

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handleTogglePipeline(BuildContext context, AudioPipelineService service) async {
    if (!service.isRunning) {
      // 1. Check Overlay Permission
      bool hasOverlayPermission = await OverlayService.hasPermission();
      if (!hasOverlayPermission) {
        await OverlayService.requestPermission();
        hasOverlayPermission = await OverlayService.hasPermission();
      }

      if (!hasOverlayPermission) {
        if (!context.mounted) return; // Safety check after await
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Overlay permission is required")),
        );
        return;
      }

      // 2. Check Microphone Permission safely
      var micStatus = await Permission.microphone.status;

      if (micStatus.isPermanentlyDenied) {
        if (!context.mounted) return;
        _showSettingsDialog(context, "Microphone access is permanently denied. Please enable it in system settings.");
        return;
      }

      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
      }

      if (micStatus.isGranted) {
        service.startPipeline();
        await OverlayService.startOverlay();
      } else {
        if (!context.mounted) return; // Safety check after await

        // Catch the scenario where they just denied it during the request
        if (micStatus.isPermanentlyDenied) {
          _showSettingsDialog(context, "Microphone access is permanently denied. Please enable it in system settings.");
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Microphone permission is required for transcription")),
          );
        }
      }
    } else {
      // Stopping
      service.stopPipeline();
      await OverlayService.stopOverlay();
    }
  }

  // Helper method to direct users to app settings
  void _showSettingsDialog(BuildContext context, String message) {
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
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Indicator
            _StatusCard(isRunning: pipeline.isRunning),

            const SizedBox(height: 60),

            // Main Action Button
            _StartStopButton(
              isRunning: pipeline.isRunning,
              onPressed: () => _handleTogglePipeline(context, pipeline),
            ),

            const SizedBox(height: 40),

            // Mic Visualizer Section
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                MicInputVisualizer(),
                SizedBox(height: 20),
                Icon(Icons.mic, size: 40),
              ],
            ),

            const SizedBox(height: 30),

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
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool isRunning;
  const _StatusCard({required this.isRunning});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isRunning
            ? colorScheme.primaryContainer.withAlpha(76)
            : colorScheme.surfaceContainerHighest.withAlpha(76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRunning ? colorScheme.primary : colorScheme.outline,
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
              color: isRunning ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              boxShadow: isRunning ? [
                BoxShadow(
                  color: Colors.green.withAlpha(127),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ] : [],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isRunning ? "SERVICE RUNNING" : "SERVICE STOPPED",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: isRunning ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartStopButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onPressed;

  const _StartStopButton({required this.isRunning, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRunning ? colorScheme.errorContainer : colorScheme.primaryContainer,
          boxShadow: [
            BoxShadow(
              color: (isRunning ? colorScheme.error : colorScheme.primary).withAlpha(76),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 80,
              color: isRunning ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
            ),
            Text(
              isRunning ? "STOP" : "START",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isRunning ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}