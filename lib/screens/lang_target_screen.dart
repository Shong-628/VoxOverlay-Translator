// lang_target_screen.dart

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../db/database_helper.dart';
import '../models/user_preference.dart';

class LangTargetScreen extends StatefulWidget {
  const LangTargetScreen({super.key});

  @override
  State<LangTargetScreen> createState() => _LangTargetScreenState();
}

class _LangTargetScreenState extends State<LangTargetScreen> {
  final List<String> languages = ["None", "English", "Malay", "Chinese"];
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
      selectedLanguage = prefs.targetLanguageCode.isNotEmpty
          ? prefs.targetLanguageCode
          : "None";
    });
  }

  Future<void> _updatePreference(String language) async {
    final prefs = await DatabaseHelper.instance.getPreferences();

    final updatedPrefs = UserPreference(
      prefId: prefs.prefId,
      sourceLanguageCode: prefs.sourceLanguageCode,
      targetLanguageCode: language,
      fontSizeScale: prefs.fontSizeScale,
      overlayOpacity: prefs.overlayOpacity,
      textColorHex: prefs.textColorHex,
      bgColorHex: prefs.bgColorHex,
      isTutorialCompleted: prefs.isTutorialCompleted,
    );

    await DatabaseHelper.instance.updatePreferences(updatedPrefs);

    Fluttertoast.showToast(msg: "Target language set to $language");

    setState(() {
      selectedLanguage = language;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
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
        title: const Text("Select Target Language"),
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