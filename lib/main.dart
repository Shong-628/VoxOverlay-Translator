import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/translation_service.dart';
import 'services/audio_pipeline_service.dart';
import 'services/settings_controller.dart';

import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/home_screen.dart';

import 'l10n/app_localizations.dart';
import 'db/database_helper.dart';

import 'overlay/overlay_service.dart';
import 'overlay/overlay_entry.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayApp(),
  ));
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
  final AudioPipelineService _audioPipeline = AudioPipelineService();
  final TranslationService _translationService = TranslationService();

  bool _initialized = false;
  bool _tutorialDone = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _settingsController.loadSettings();
      final prefs = await DatabaseHelper.instance.getPreferences();
      _tutorialDone = prefs.isTutorialCompleted;

      _setupOverlayListener();

      // Increased timeout to 3 minutes. Initial download of 3 ML Kit models
      // can take a while on slower networks. Subsequent app launches will
      // skip the download and pass this in milliseconds.
      await Future.wait([
        _audioPipeline.initialize(),
        _translationService.initialize(),
      ]).timeout(const Duration(minutes: 3));

    } catch (e) {
      debugPrint("Initialization warning/error: $e");
    } finally {
      if (mounted) {
        setState(() => _initialized = true);
      }
    }
  }

  void _setupOverlayListener() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      OverlayService.handleSystemMessage(data);

      if (data is Map && data.containsKey('action')) {
        switch (data['action']) {
          case 'toggle':
            _audioPipeline.togglePipeline();
            break;
          case 'settings':
            _audioPipeline.stopPipeline();
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
            break;
          case 'close':
            _audioPipeline.stopPipeline();
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true), // Dark theme looks better for loading
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 30),
                  const Text(
                    "Setting up VoxOverlay",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  // ListenableBuilder listens to the TranslationService
                  // and updates this text dynamically as models download
                  ListenableBuilder(
                    listenable: _translationService,
                    builder: (context, child) {
                      return Text(
                        _translationService.setupStatus,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _settingsController),
        ChangeNotifierProvider.value(value: _audioPipeline),
        ChangeNotifierProvider.value(value: _translationService),
      ],
      child: VoxOverlayApp(isTutorialCompleted: _tutorialDone),
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