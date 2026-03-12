// translation_service.dart
// translation_service.dart
import 'dart:developer' as dev;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../db/database_helper.dart';

class TranslationService {
  OnDeviceTranslator? _translator;
  final _modelManager = OnDeviceTranslatorModelManager();

  // Track current pair to avoid re-initializing the engine unnecessarily
  String _currentSourcePref = "";
  String _currentTargetPref = "";

  /// Maps your database/UI strings to Google ML Kit's TranslateLanguage Enums
  TranslateLanguage _mapLanguageToEnum(String languageName) {
    switch (languageName.toLowerCase()) {
      case 'english':
        return TranslateLanguage.english;
      case 'malay':
        return TranslateLanguage.malay;
      case 'chinese':
        return TranslateLanguage.chinese;
    // Note: ML Kit Translation doesn't support 'Auto' natively in the translator instance.
    // To support 'Auto', you would use the separate `google_mlkit_language_id` package first.
    // For now, defaulting to English to prevent crashes.
      case 'auto':
        return TranslateLanguage.english;
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

  /// Translates the text based on current DB preferences
  Future<String> translate(String text) async {
    if (text.isEmpty) return "";

    try {
      // 1. Fetch latest preferences
      final prefs = await DatabaseHelper.instance.getPreferences();
      final sourcePref = prefs.sourceLanguageCode;
      final targetPref = prefs.targetLanguageCode;

      // 2. Early Exits
      if (targetPref.toLowerCase() == 'none' || sourcePref.toLowerCase() == targetPref.toLowerCase()) {
        return text;
      }

      // 3. Convert string preferences to ML Kit enums
      final sourceLang = _mapLanguageToEnum(sourcePref);
      final targetLang = _mapLanguageToEnum(targetPref);

      // 4. Initialize or Update the Translator ONLY if the language pair changed
      if (_translator == null || _currentSourcePref != sourcePref || _currentTargetPref != targetPref) {

        // Close old translator to free up memory before making a new one
        _translator?.close();

        // Make sure the ML models are on the device (requires internet the very first time)
        await _ensureModelsDownloaded(sourceLang, targetLang);

        _translator = OnDeviceTranslator(
          sourceLanguage: sourceLang,
          targetLanguage: targetLang,
        );

        _currentSourcePref = sourcePref;
        _currentTargetPref = targetPref;
        dev.log("Translator initialized for: ${sourceLang.name} -> ${targetLang.name}", name: 'TranslationService');
      }

      // 5. Direct translation (ML Kit handles pivoting internally!)
      final String result = await _translator!.translateText(text);
      return result;

    } catch (e, stackTrace) {
      dev.log(
        "Translation error",
        name: 'TranslationService',
        error: e,
        stackTrace: stackTrace,
      );
      return text;
    }
  }

  /// Clean up resources when your app closes or the service is destroyed
  void dispose() {
    _translator?.close();
  }
}