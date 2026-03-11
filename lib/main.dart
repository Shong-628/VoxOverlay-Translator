import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'overlay/subtitle_overlay_screen.dart';
import 'services/audio_pipeline_service.dart';

// Global keys and services for easy access from the listener
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final AudioPipelineService audioPipelineService = AudioPipelineService();

/// This is the entry point for the overlay process
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SubtitleOverlay(),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the audio pipeline service
  await audioPipelineService.initialize();

  // Inside your Main App's initialization
  FlutterOverlayWindow.overlayListener.listen((data) {
    if (data is Map && data.containsKey('action')) {
      switch (data['action']) {
        case 'toggle':
          // logic to start/stop AudioPipelineService
          audioPipelineService.togglePipeline();
          break;
        case 'settings':
          // Use a navigation key to open settings or bring app to front
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
          break;
        case 'close':
          exit(0); // Terminate app
      }
    }
  });

  runApp(const VoxOverlayApp());
}

class VoxOverlayApp extends StatelessWidget {
  const VoxOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'VoxOverlay Translator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const OnboardingScreen(),
    );
  }
}
