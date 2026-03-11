import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {

  static Future<void> saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("language", language);
  }

  static Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("language");
  }
}