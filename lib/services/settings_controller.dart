import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  // Constants to prevent typos
  static const String _keyDarkMode = 'darkMode';
  static const String _keyAppLanguage = 'appLanguage';

  bool darkMode = true;
  String appLanguage = "English";

  SharedPreferences? _prefs;

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

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> loadSettings() async {
    await _initPrefs();

    darkMode = _prefs!.getBool(_keyDarkMode) ?? true;
    appLanguage = _prefs!.getString(_keyAppLanguage) ?? "English";

    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    notifyListeners(); // Update UI instantly

    await _initPrefs();
    await _prefs!.setBool(_keyDarkMode, value);
  }

  Future<void> setLanguage(String value) async {
    appLanguage = value;
    notifyListeners(); // Update UI instantly

    await _initPrefs();
    await _prefs!.setString(_keyAppLanguage, value);
  }
}