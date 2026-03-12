// main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:provider/provider.dart'; // ADD
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'services/audio_pipeline_service.dart';
import 'overlay/overlay_entry.dart';
import 'screens/home_screen.dart';
import 'services/settings_controller.dart'; // ADD
import 'package:flutter_localizations/flutter_localizations.dart';
import '../l10n/app_localizations.dart';

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

  // Initialize global settings controller
  final settingsController = SettingsController();
  await settingsController.loadSettings();

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

  runApp(
    ChangeNotifierProvider(
      create: (_) => settingsController,
      child: const VoxOverlayApp(),
    ),
  );
}

class VoxOverlayApp extends StatelessWidget {
  const VoxOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return MaterialApp(
      navigatorKey: navigatorKey, // Required for the settings navigation to work
      title: 'VoxOverlay Translator',
      debugShowCheckedModeBanner: false,

      // THEME CONTROL
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: settings.themeMode,

      // LANGUAGE CONTROL
      locale: settings.locale,
      supportedLocales: const [
        Locale("en"),
        Locale("ms"),
        Locale("zh"),
      ],

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const HomeScreen(),
    );
  }
}