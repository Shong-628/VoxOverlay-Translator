// lib/translation_service.dart
import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../db/database_helper.dart';

class TranslationService extends ChangeNotifier {
  final OnDeviceTranslatorModelManager _modelManager = OnDeviceTranslatorModelManager();
  final Map<String, OnDeviceTranslator> _translatorCache = {};

  // NEW: Keep track of confirmed downloaded models to prevent network calls
  final Set<String> _downloadedModels = {};

  String _sourcePref = "";
  String _targetPref = "";

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String _setupStatus = "Initializing translation engine...";
  String get setupStatus => _setupStatus;

  Timer? _debounceTimer;
  Completer<String>? _activeCompleter;
  String _lastInput = "";
  String _lastOutput = "";

  static const supportedLanguages = [
    TranslateLanguage.english,
    TranslateLanguage.malay,
    TranslateLanguage.chinese,
  ];

  Future<void> initialize() async {
    final prefs = await DatabaseHelper.instance.getPreferences();

    _sourcePref = prefs.sourceLanguageCode;
    _targetPref = prefs.targetLanguageCode;

    await _predownloadModels();

    _isInitialized = true;
    _setupStatus = "Ready";
    notifyListeners();

    dev.log("TranslationService initialized", name: "TranslationService");
  }

  TranslateLanguage _mapLanguage(String name) {
    switch (name.toLowerCase()) {
      case 'english':
        return TranslateLanguage.english;
      case 'malay':
        return TranslateLanguage.malay;
      case 'chinese':
        return TranslateLanguage.chinese;
      default:
        return TranslateLanguage.english;
    }
  }

  Future<void> _predownloadModels() async {
    final futures = supportedLanguages.map((lang) async {
      try {
        bool downloaded = await _modelManager.isModelDownloaded(lang.bcpCode);

        if (!downloaded) {
          dev.log("Downloading model: ${lang.name}", name: "TranslationService");
          _setupStatus = "Downloading offline model: ${lang.name}\n(This only happens once)";
          notifyListeners();

          // Attempt to download. This returns a boolean in newer ML Kit versions,
          // or just completes silently if successful.
          await _modelManager.downloadModel(lang.bcpCode);

          // Verify again just to be safe
          downloaded = await _modelManager.isModelDownloaded(lang.bcpCode);
        }

        // If definitively downloaded, add it to our safe list
        if (downloaded) {
          _downloadedModels.add(lang.bcpCode);
          dev.log("${lang.name} is ready for offline use.", name: "TranslationService");
        }
      } catch (e) {
        dev.log("Failed to download or verify ${lang.name}", name: "TranslationService", error: e);
      }
    });

    await Future.wait(futures);
  }

  Future<OnDeviceTranslator> _getTranslator(TranslateLanguage source, TranslateLanguage target) async {
    final key = "${source.bcpCode}_${target.bcpCode}";

    if (_translatorCache.containsKey(key)) {
      return _translatorCache[key]!;
    }

    final translator = OnDeviceTranslator(sourceLanguage: source, targetLanguage: target);
    _translatorCache[key] = translator;
    return translator;
  }

  Future<String> translate(String text) async {
    text = text.trim();
    if (text.isEmpty || !_isInitialized) return text;

    if (_targetPref.toLowerCase() == 'none' ||
        _sourcePref.toLowerCase() == _targetPref.toLowerCase()) {
      return text;
    }

    if (text == _lastInput) {
      return _lastOutput;
    }

    final sourceLang = _mapLanguage(_sourcePref);
    final targetLang = _mapLanguage(_targetPref);

    // NEW STRICT OFFLINE CHECK: If models aren't locally verified, bypass ML Kit entirely
    if (!_downloadedModels.contains(sourceLang.bcpCode) ||
        !_downloadedModels.contains(targetLang.bcpCode)) {
      dev.log("Models missing offline. Passing through raw text.", name: "TranslationService");
      return text;
    }

    _debounceTimer?.cancel();

    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete(_lastOutput.isNotEmpty ? _lastOutput : text);
    }

    final completer = Completer<String>();
    _activeCompleter = completer;

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final translator = await _getTranslator(sourceLang, targetLang);
        final result = await translator.translateText(text);

        _lastInput = text;
        _lastOutput = result;

        if (!completer.isCompleted) completer.complete(result);
      } catch (e) {
        dev.log("Translation error", name: "TranslationService", error: e);
        if (!completer.isCompleted) completer.complete(text);
      }
    });

    return completer.future;
  }

  void resetCache() {
    _lastInput = "";
    _lastOutput = "";
    _debounceTimer?.cancel();
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete("");
    }
  }

  Future<void> reloadPreferences() async {
    final prefs = await DatabaseHelper.instance.getPreferences();
    _sourcePref = prefs.sourceLanguageCode;
    _targetPref = prefs.targetLanguageCode;
    dev.log("Translation preferences instantly updated: $_sourcePref -> $_targetPref", name: "TranslationService");
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete("");
    }
    for (final translator in _translatorCache.values) {
      translator.close();
    }
    _translatorCache.clear();
    super.dispose();
  }
}