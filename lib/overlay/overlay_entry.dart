// overlay_entry.dart
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'floating_bubble.dart';
import '../models/user_preference.dart';

// NEW: Import the ML and Audio services
import '../services/translation_service.dart';
import '../services/audio_pipeline_service.dart';

class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});
  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  String subtitle = "";
  UserPreference? _currentPrefs;

  // Local ML Services
  late final TranslationService _translationService;
  late final AudioPipelineService _audioPipeline;
  bool _servicesReady = false;

  // Track pipeline state locally
  bool _isRunning = false;
  bool _isPaused = false;

  // Port to receive commands from the floating bubble
  final ReceivePort _localPort = ReceivePort();

  @override
  void initState() {
    super.initState();
    _setupLocalServices();
    _setupOverlayListener();
    _setupLocalActionPort();

    // Delay the "ready" ping until after the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterOverlayWindow.shareData({"status": "ready"});
    });
  }

  Future<void> _setupLocalServices() async {
    _translationService = TranslationService();
    _audioPipeline = AudioPipelineService(translationService: _translationService);

    // Initialize the heavy ML models locally in the background
    await Future.wait([
      _translationService.initialize(),
      _audioPipeline.initialize(),
    ]);

    // Listen to local pipeline state changes to update the bubble UI
    _audioPipeline.addListener(() {
      if (mounted) {
        setState(() {
          // Assuming your pipeline exposes these getters. Adjust if needed.
          _isRunning = _audioPipeline.isRunning;
          _isPaused = _audioPipeline.isPaused;
        });
      }
    });

    if (mounted) {
      setState(() => _servicesReady = true);
    }
  }

  void _setupLocalActionPort() {
    // Hijack the port name so the floating bubble talks directly to this isolate
    ui.IsolateNameServer.removePortNameMapping('vox_overlay_port');
    ui.IsolateNameServer.registerPortWithName(_localPort.sendPort, 'vox_overlay_port');

    _localPort.listen((message) {
      if (message is String && message.startsWith("ACTION_PREFIX:")) {
        final action = message.replaceFirst("ACTION_PREFIX:", "");
        _handleLocalAction(action);
      }
    });
  }

  void _handleLocalAction(String action) {
    if (!_servicesReady) return;

    switch (action) {
      case 'toggle':
        _audioPipeline.togglePipeline();
        break;

      case 'close':
        _audioPipeline.stopPipeline();
        FlutterOverlayWindow.closeOverlay();
        break;

      case 'settings':
        _audioPipeline.forcePause();
        // Send a message BACK to the main app to wake it up and open settings
        FlutterOverlayWindow.shareData({
          "type": "overlay_action",
          "action": "open_settings"
        });
        break;
    }
  }

  void _setupOverlayListener() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (!mounted || data == null) return;

      if (data is Map) {
        if (data.containsKey('target_language_code') || data.containsKey('fontSizeScale')) {
          // Sync preferences from the Main App
          setState(() {
            _currentPrefs = UserPreference.fromMap(Map<String, dynamic>.from(data));
          });

          // TODO: If your translation service needs to know when language changes,
          // you can pass the new language code to it right here!
          // e.g., _translationService.updateLanguage(_currentPrefs!.targetLanguageCode);
        }
      }
      else if (data is String) {
        // We still listen for strings here in case your AudioPipelineService
        // uses FlutterOverlayWindow.shareData(text) under the hood to publish subtitles.
        if (!data.startsWith("ACTION_PREFIX:")) {
          setState(() => subtitle = data);
        }
      }
    });
  }

  @override
  void dispose() {
    ui.IsolateNameServer.removePortNameMapping('vox_overlay_port');
    _localPort.close();

    // Clean up ML models when overlay is destroyed
    _audioPipeline.dispose();
    _translationService.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hold a transparent placeholder that exactly matches the 100x100 
    // _initialSize we defined in OverlayService until preferences arrive.
    if (_currentPrefs == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox(
          width: 100,
          height: 100,
        ),
      );
    }

    return FloatingBubble(
      text: subtitle,
      prefs: _currentPrefs!,
      isRunning: _isRunning,
      isPaused: _isPaused,
    );
  }
}