// widgets/test_translate.dart

import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationTestWidget extends StatefulWidget {
  const TranslationTestWidget({super.key});

  @override
  State<TranslationTestWidget> createState() => _TranslationTestWidgetState();
}

class _TranslationTestWidgetState extends State<TranslationTestWidget> {
  // Hardcoded test parameters
  final TranslateLanguage _sourceLang = TranslateLanguage.english;
  final TranslateLanguage _targetLang = TranslateLanguage.malay;
  final String _testInput = "Hello, how are you?";

  String _translatedText = "";
  String _statusMessage = "Ready to test";

  bool _isTesting = false;
  bool? _isSuccess;

  Future<void> _runTest() async {
    setState(() {
      _isTesting = true;
      _isSuccess = null;
      _translatedText = "";
      _statusMessage = "Downloading models (this may take a moment)...";
    });

    try {
      final modelManager = OnDeviceTranslatorModelManager();

      // 1. Ensure models are downloaded locally
      await modelManager.downloadModel(_sourceLang.bcpCode);
      await modelManager.downloadModel(_targetLang.bcpCode);

      setState(() {
        _statusMessage = "Models ready. Translating...";
      });

      // 2. Initialize the Translator
      final translator = OnDeviceTranslator(
        sourceLanguage: _sourceLang,
        targetLanguage: _targetLang,
      );

      // 3. Perform the Translation
      final result = await translator.translateText(_testInput);

      // 4. Dispose the translator to prevent memory leaks
      await translator.close();

      setState(() {
        _translatedText = result;
        // Verify it actually translated (not empty, and not identical to input)
        _isSuccess = result.isNotEmpty && result.toLowerCase() != _testInput.toLowerCase();
        _statusMessage = _isSuccess == true
            ? "✓ Translation successful"
            : "⚠ Translation failed or returned identical text";
      });

    } catch (e) {
      setState(() {
        _isSuccess = false;
        _statusMessage = "Error: $e";
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.translate, size: 20),
            SizedBox(width: 8),
            Text(
              "Translation Test",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        const Text(
          "Verifies that Google ML Kit models download and translate text correctly.",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 20),

        // Input & Output Display Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Input (${_sourceLang.name}):", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(_testInput),
              const Divider(height: 20),
              Text("Output (${_targetLang.name}):", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                _translatedText.isEmpty ? "..." : _translatedText,
                style: TextStyle(
                  color: _isSuccess == true ? Colors.green : null,
                  fontStyle: _translatedText.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Status Indicator
        Text(
          _statusMessage,
          style: TextStyle(
            color: _isSuccess == true
                ? Colors.green
                : (_isSuccess == false ? Colors.red : Colors.grey),
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 20),

        // Action Button
        ElevatedButton.icon(
          onPressed: _isTesting ? null : _runTest,
          icon: _isTesting
              ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)
          )
              : const Icon(Icons.play_arrow),
          label: Text(_isTesting ? "Testing..." : "Run Translation Test"),
        ),
      ],
    );
  }
}