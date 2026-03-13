// home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_pipeline_service.dart';
import '../overlay/overlay_service.dart';
import 'settings_screen.dart';
import 'onboarding_screen.dart';
import '../db/database_helper.dart';
import '../models/user_preference.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handleTogglePipeline(BuildContext context, AudioPipelineService service) async {
    if (!service.isRunning) {
      // Starting
      bool hasPermission = await OverlayService.hasPermission();
      if (!hasPermission) {
        await OverlayService.requestPermission();
        hasPermission = await OverlayService.hasPermission();
      }

      if (hasPermission) {
        service.startPipeline();
        // Overlay will be started by the service when data is available, 
        // or we can explicitly start it here to show feedback.
        await OverlayService.startOverlay();
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Overlay permission is required")),
          );
        }
      }
    } else {
      // Stopping
      service.stopPipeline();
      await OverlayService.stopOverlay();
    }
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
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
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
            
            Text(
              pipeline.isRunning 
                  ? "Translation is active.\nCheck the overlay for subtitles."
                  : "Ready to translate.\nTap the button to start.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
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
            ? colorScheme.primaryContainer.withValues(alpha: 0.3) 
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                  color: Colors.green.withValues(alpha: 0.5),
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
              color: (isRunning ? colorScheme.error : colorScheme.primary).withValues(alpha: 0.3),
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
