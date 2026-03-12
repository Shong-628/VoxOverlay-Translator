import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  bool darkMode = true;
  String appLanguage = "English";

  Locale get locale {
    switch (appLanguage) {
      case "Malay":
        return const Locale("ms");
      case "Chinese":
        return const Locale("zh");
      default:
        return const Locale("en");
    }
  }

  ThemeMode get themeMode {
    return darkMode ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    darkMode = prefs.getBool('darkMode') ?? true;
    appLanguage = prefs.getString('appLanguage') ?? "English";

    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);

    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    appLanguage = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appLanguage', value);

    notifyListeners();
  }
}