import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../db/database_helper.dart';

class TranslationService extends ChangeNotifier {
  final OnDeviceTranslatorModelManager _modelManager =
  OnDeviceTranslatorModelManager();

  final Map<String, OnDeviceTranslator> _translatorCache = {};

  String _sourcePref = "";
  String _targetPref = "";

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Supported languages for the app
  static const supportedLanguages = [
    TranslateLanguage.english,
    TranslateLanguage.malay,
    TranslateLanguage.chinese,
  ];

  /// Initializes translation system and downloads required models
  Future<void> initialize() async {
    final prefs = await DatabaseHelper.instance.getPreferences();

    _sourcePref = prefs.sourceLanguageCode;
    _targetPref = prefs.targetLanguageCode;

    await _predownloadModels();

    _isInitialized = true;
    notifyListeners();

    dev.log("TranslationService initialized", name: "TranslationService");
  }

  /// Maps stored names to ML Kit enums
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

  /// Downloads all supported models in parallel
  Future<void> _predownloadModels() async {
    final futures = supportedLanguages.map((lang) async {
      final downloaded = await _modelManager.isModelDownloaded(lang.bcpCode);

      if (!downloaded) {
        dev.log("Downloading model: ${lang.name}",
            name: "TranslationService");
        await _modelManager.downloadModel(lang.bcpCode);
      }
    });

    await Future.wait(futures);
  }

  /// Returns cached translator or creates a new one
  Future<OnDeviceTranslator> _getTranslator(
      TranslateLanguage source,
      TranslateLanguage target,
      ) async {
    final key = "${source.bcpCode}_${target.bcpCode}";

    if (_translatorCache.containsKey(key)) {
      return _translatorCache[key]!;
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );

    _translatorCache[key] = translator;

    dev.log("Translator cached: $key", name: "TranslationService");

    return translator;
  }

  /// Main translation function
  Future<String> translate(String text) async {
    if (text.isEmpty || !_isInitialized) return text;

    if (_targetPref.toLowerCase() == 'none' ||
        _sourcePref.toLowerCase() == _targetPref.toLowerCase()) {
      return text;
    }

    try {
      final sourceLang = _mapLanguage(_sourcePref);
      final targetLang = _mapLanguage(_targetPref);

      final translator = await _getTranslator(sourceLang, targetLang);

      return await translator.translateText(text);
    } catch (e, stackTrace) {
      dev.log(
        "Translation error",
        name: "TranslationService",
        error: e,
        stackTrace: stackTrace,
      );

      return text;
    }
  }

  /// Update preferences when user changes settings
  Future<void> reloadPreferences() async {
    final prefs = await DatabaseHelper.instance.getPreferences();

    _sourcePref = prefs.sourceLanguageCode;
    _targetPref = prefs.targetLanguageCode;

    dev.log(
      "Preferences updated: $_sourcePref -> $_targetPref",
      name: "TranslationService",
    );
  }

  /// Dispose all cached translators
  @override
  void dispose() {
    for (final translator in _translatorCache.values) {
      translator.close();
    }

    _translatorCache.clear();

    super.dispose();
  }
}