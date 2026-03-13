// translation_service.dart
import 'dart:developer' as dev;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../db/database_helper.dart';

class TranslationService {
  OnDeviceTranslator? _translator;
  final _modelManager = OnDeviceTranslatorModelManager();

  String _currentSourcePref = "";
  String _currentTargetPref = "";
  bool _isInitialized = false;

  /// Call this once when the app starts, and whenever the user changes settings in the UI
  Future<void> loadPreferences() async {
    final prefs = await DatabaseHelper.instance.getPreferences();
    _currentSourcePref = prefs.sourceLanguageCode;
    _currentTargetPref = prefs.targetLanguageCode;
    _isInitialized = true;
    dev.log("Translation preferences loaded: $_currentSourcePref -> $_currentTargetPref", name: 'TranslationService');
  }

  /// Maps database/UI strings to Google ML Kit's TranslateLanguage Enums
  TranslateLanguage _mapLanguageToEnum(String languageName) {
    switch (languageName.toLowerCase()) {
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

  /// Checks if models exist on device, and downloads them if they don't.
  Future<void> _ensureModelsDownloaded(TranslateLanguage source, TranslateLanguage target) async {
    final bool isSourceDownloaded = await _modelManager.isModelDownloaded(source.bcpCode);
    final bool isTargetDownloaded = await _modelManager.isModelDownloaded(target.bcpCode);

    if (!isSourceDownloaded) {
      dev.log("Downloading source model: ${source.name}...", name: 'TranslationService');
      await _modelManager.downloadModel(source.bcpCode);
    }

    if (!isTargetDownloaded) {
      dev.log("Downloading target model: ${target.name}...", name: 'TranslationService');
      await _modelManager.downloadModel(target.bcpCode);
    }
  }

  /// Translates the text based on cached preferences
  Future<String> translate(String text) async {
    if (text.isEmpty) return "";

    try {
      // Ensure we have preferences loaded
      if (!_isInitialized) {
        await loadPreferences();
      }

      // 1. Early Exits
      if (_currentTargetPref.toLowerCase() == 'none' ||
          _currentSourcePref.toLowerCase() == _currentTargetPref.toLowerCase()) {
        return text;
      }

      // 2. Convert string preferences to ML Kit enums
      final sourceLang = _mapLanguageToEnum(_currentSourcePref);
      final targetLang = _mapLanguageToEnum(_currentTargetPref);

      // 3. Initialize or Update the Translator ONLY if it hasn't been set up yet
      // (If languages change, loadPreferences() should be called, which will trigger a re-init here if we added logic for it,
      // but to keep it simple, we check if the translator matches our current cache)
      if (_translator == null) {
        await _setupNewTranslator(sourceLang, targetLang);
      }

      // 4. Direct translation
      final String result = await _translator!.translateText(text);
      return result;

    } catch (e, stackTrace) {
      dev.log("Translation error", name: 'TranslationService', error: e, stackTrace: stackTrace);
      return text;
    }
  }

  Future<void> _setupNewTranslator(TranslateLanguage sourceLang, TranslateLanguage targetLang) async {
    _translator?.close(); // Close old translator
    await _ensureModelsDownloaded(sourceLang, targetLang);

    _translator = OnDeviceTranslator(
      sourceLanguage: sourceLang,
      targetLanguage: targetLang,
    );
    dev.log("Translator initialized for: ${sourceLang.name} -> ${targetLang.name}", name: 'TranslationService');
  }

  /// Clean up resources when your app closes
  void dispose() {
    _translator?.close();
  }
}