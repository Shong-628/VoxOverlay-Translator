// lib/screens/lang_source_screen.dart
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart'; // NEW: Added Provider import

import '../db/database_helper.dart';
import '../models/user_preference.dart';
import '../overlay/overlay_service.dart';
import '../services/translation_service.dart'; // NEW: Adjust this path if your TranslationService is in a different folder

class LangSourceScreen extends StatefulWidget {
  const LangSourceScreen({super.key});

  @override
  State<LangSourceScreen> createState() => _LangSourceScreenState();
}

class _LangSourceScreenState extends State<LangSourceScreen> {
  final List<String> languages = ["English", "Malay", "Chinese"];
  String searchText = "";
  String? selectedLanguage;

  @override
  void initState() {
    super.initState();
    _loadCurrentPreference();
  }

  Future<void> _loadCurrentPreference() async {
    final prefs = await DatabaseHelper.instance.getPreferences();
    setState(() {
      selectedLanguage = prefs.sourceLanguageCode;
    });
  }

  Future<void> _updatePreference(String language) async {
    final prefs = await DatabaseHelper.instance.getPreferences();

    final updatedPrefs = UserPreference(
      prefId: prefs.prefId,
      sourceLanguageCode: language,
      targetLanguageCode: prefs.targetLanguageCode,
      fontSizeScale: prefs.fontSizeScale,
      overlayOpacity: prefs.overlayOpacity,
      textColorHex: prefs.textColorHex,
      bgColorHex: prefs.bgColorHex,
      isTutorialCompleted: prefs.isTutorialCompleted,
    );

    // 1. Save to database
    await DatabaseHelper.instance.updatePreferences(updatedPrefs);

    // 2. INSTANT SYNC: Push to the active overlay immediately
    await OverlayService.syncPreferences(updatedPrefs);

    // 3. INSTANT SYNC: Update the translation engine logic
    if (mounted) {
      context.read<TranslationService>().reloadPreferences();
    }

    Fluttertoast.showToast(msg: "Source language set to $language");

    setState(() {
      selectedLanguage = language;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Navigator.pop(context, language);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = languages
        .where((lang) => lang.toLowerCase().contains(searchText.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Source Language"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Search language",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (text) {
                setState(() {
                  searchText = text;
                });
              },
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final language = filtered[index];
          return RadioListTile<String>(
            title: Text(language),
            value: language,
            groupValue: selectedLanguage,
            onChanged: (value) {
              if (value != null) _updatePreference(value);
            },
          );
        },
      ),
    );
  }
}