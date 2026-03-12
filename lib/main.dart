// main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'services/audio_pipeline_service.dart';
import 'overlay/overlay_entry.dart';
import 'screens/home_screen.dart';

// Global keys and services
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final AudioPipelineService audioPipelineService = AudioPipelineService();

// 2. Ensure this is exactly as named in the plugin's expectations
// The @pragma ensures the function isn't "cleaned away" during release builds.
@pragma("vm:entry-point")
void overlayMain() {
  // This calls the function you defined in overlay_entry.dart
  // Make sure the function name matches exactly.
  runOverlayApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the audio pipeline
  await audioPipelineService.initialize();

  // Listen for actions sent FROM the Overlay bubble TO the Main App
  FlutterOverlayWindow.overlayListener.listen((data) {
    if (data is Map && data.containsKey('action')) {
      final String action = data['action'];

      switch (action) {
        case 'toggle':
          audioPipelineService.togglePipeline();
          break;

        case 'settings':
        // Navigate to settings screen
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
          break;

        case 'close':
          exit(0);

        case 'minimize':
        // Optional: Add logic here if you want to hide the overlay
          break;
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
      navigatorKey: navigatorKey, // Required for the settings navigation to work
      title: 'VoxOverlay Translator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(), // From your home_screen.dart
    );
  }
}