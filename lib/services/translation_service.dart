import 'dart:developer' as dev;
import 'package:argos_translator_offline/argos_translate_dart.dart';
// import 'package:argos_translator_offline/bindings.dart';

class TranslationService {
  String _sourceLang = "en";
  String _targetLang = "ms";

  /// Initialize and set language pairs
  Future<void> loadModel(String sourceLang, String targetLang) async {
    // We store these to determine if we need a pivot translation later
    _sourceLang = sourceLang;
    _targetLang = targetLang;

    dev.log("Translation service configured for: $sourceLang -> $targetLang", name: 'TranslationService');
  }

  /// Translate text with pivot logic for Malay <-> Chinese
  Future<String> translate(String text) async {
    if (text.isEmpty) return "";

    try {
      // Logic: Malay to Chinese (or vice versa) requires English as a pivot
      if (_isPivotRequired(_sourceLang, _targetLang)) {
        return await _translateWithPivot(text, _sourceLang, _targetLang);
      }

      // Direct translation for other pairs
      return await _directTranslate(text, _sourceLang, _targetLang);
    } catch (e, stackTrace) {
      dev.log(
        "Translation error",
        name: 'TranslationService',
        error: e,
        stackTrace: stackTrace,
      );
      return text; // Fallback to original text on error
    }
  }

  /// Check if the language pair requires a pivot through English
  bool _isPivotRequired(String source, String target) {
    return (source == "ms" && target == "zh") || (source == "zh" && target == "ms");
  }

  /// Handles the MS -> EN -> ZH or ZH -> EN -> MS flow
  Future<String> _translateWithPivot(String text, String from, String to) async {
    dev.log("Using English as pivot for $from to $to", name: 'TranslationService');

    // Step 1: Translate source to English
    final String pivotText = await _directTranslate(text, from, "en");

    // Step 2: Translate English to target
    return await _directTranslate(pivotText, "en", to);
  }

  /// Wrapper for the static library call
  Future<String> _directTranslate(String text, String from, String to) async {
    // Based on your sample: ArgosTranslate.translate(original, fromLang, toLang)
    final result = await ArgosTranslate.translate(text, from, to);
    return result ?? text;
  }
}