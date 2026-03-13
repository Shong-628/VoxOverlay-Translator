// main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/home_screen.dart';
import 'services/audio_pipeline_service.dart';
import 'services/settings_controller.dart';
import 'overlay/overlay_entry.dart';
import 'l10n/app_localizations.dart';
import 'db/database_helper.dart';

// Global keys and services
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final AudioPipelineService audioPipelineService = AudioPipelineService();

@pragma("vm:entry-point")
void overlayMain() {
  runOverlayApp();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppInitializer());
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  final SettingsController _settingsController = SettingsController();
  bool _isInitialized = false;
  bool _isTutorialCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await audioPipelineService.initialize();
    await _settingsController.loadSettings();

    final prefs = await DatabaseHelper.instance.getPreferences();
    _isTutorialCompleted = prefs.isTutorialCompleted;

    _setupOverlayListener();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _setupOverlayListener() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map && data.containsKey('action')) {
        final String action = data['action'];

        switch (action) {
          case 'toggle':
            audioPipelineService.togglePipeline();
            break;

          case 'settings':
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
            break;

          case 'close':
            exit(0);

          case 'minimize':
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _settingsController),
        ChangeNotifierProvider.value(value: audioPipelineService),
      ],
      child: VoxOverlayApp(isTutorialCompleted: _isTutorialCompleted),
    );
  }
}

class VoxOverlayApp extends StatelessWidget {
  final bool isTutorialCompleted;
  const VoxOverlayApp({super.key, required this.isTutorialCompleted});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'VoxOverlay Translator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: settings.themeMode,
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
      home: isTutorialCompleted ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
