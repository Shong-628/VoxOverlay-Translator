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

// overlay entry point
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
    await Future.wait([
      _audioPipeline.initialize(),
      _settingsController.loadSettings(),
      _translationService.initialize(),
    ]);

    final prefs = await DatabaseHelper.instance.getPreferences();
    _tutorialDone = prefs.isTutorialCompleted;

    _setupOverlayListener();

    if (mounted) {
      setState(() => _initialized = true);
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
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
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
