// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/user_preference.dart';
import 'lang_source_screen.dart';
import 'lang_target_screen.dart';
import 'package:provider/provider.dart';
import '../services/settings_controller.dart';
import '../extensions/context_extensions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // DB Preferences (Subtitle Settings)
  UserPreference? _userPrefs;
  String sourceLanguage = "English";
  String targetLanguage = "None";
  double fontSize = 18.0;
  int opacity = 80; // Stored as 0-100 integer in DB
  String textColorHex = "#FFFFFF";
  String bgColorHex = "#000000";

  // SharedPreferences (General Settings)
  bool darkMode = true;
  String appLanguage = "English";

  // Predefined colors for the picker
  final Map<String, String> colorOptions = {
    "White": "#FFFFFF",
    "Black": "#000000",
    "Yellow": "#FFFF00",
    "Green": "#00FF00",
    "Blue": "#0000FF",
    "Red": "#FF0000",
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load Database Preferences
    final prefs = await DatabaseHelper.instance.getPreferences();

    // Load Shared Preferences
    final SharedPreferences sharedPrefs = await SharedPreferences.getInstance();

    setState(() {
      _userPrefs = prefs;
      sourceLanguage = prefs.sourceLanguageCode;
      targetLanguage = prefs.targetLanguageCode;

      // Clamped values to prevent Slider assertion errors
      fontSize = prefs.fontSizeScale.clamp(12.0, 30.0);
      opacity = prefs.overlayOpacity.clamp(20, 100);

      textColorHex = prefs.textColorHex;
      bgColorHex = prefs.bgColorHex;

      darkMode = sharedPrefs.getBool('darkMode') ?? true;
      appLanguage = sharedPrefs.getString('appLanguage') ?? "English";
    });

    // Sync global settings controller
    final controller = context.read<SettingsController>();
    controller.darkMode = darkMode;
    controller.appLanguage = appLanguage;
  }

  Future<void> _updateDbPrefs() async {
    if (_userPrefs == null) return;
    final updatedPrefs = UserPreference(
      prefId: _userPrefs!.prefId,
      sourceLanguageCode: sourceLanguage,
      targetLanguageCode: targetLanguage,
      fontSizeScale: fontSize,
      overlayOpacity: opacity,
      textColorHex: textColorHex,
      bgColorHex: bgColorHex,
      isTutorialCompleted: _userPrefs!.isTutorialCompleted,
    );
    await DatabaseHelper.instance.updatePreferences(updatedPrefs);
    _userPrefs = updatedPrefs;
  }

  Future<void> _updateSharedPrefs() async {
    final SharedPreferences sharedPrefs = await SharedPreferences.getInstance();
    await sharedPrefs.setBool('darkMode', darkMode);
    await sharedPrefs.setString('appLanguage', appLanguage);
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    if (_userPrefs == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- SECTION 1: LANGUAGE ---
          Text(
            context.loc.language,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          ListTile(
            title: Text(context.loc.sourceLanguage),
            subtitle: Text(sourceLanguage),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LangSourceScreen()),
              );
              if (result != null) {
                setState(() => sourceLanguage = result);
                // LangSourceScreen already updates the DB, just refreshing UI
                _loadSettings();
              }
            },
          ),
          ListTile(
            title: Text(context.loc.targetLanguage),
            subtitle: Text(targetLanguage),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LangTargetScreen()),
              );
              if (result != null) {
                setState(() => targetLanguage = result);
                // LangTargetScreen already updates the DB, just refreshing UI
                _loadSettings();
              }
            },
          ),
          const Divider(height: 30),

          // --- SECTION 2: SUBTITLE PREVIEW ---
          Text(
            context.loc.subtitlePreview,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: NetworkImage("https://picsum.photos/seed/picsum/400/200"), // Mock video background
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _hexToColor(bgColorHex).withOpacity(opacity / 100.0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                context.loc.subtitlePreview,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _hexToColor(textColorHex),
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
          const Divider(height: 40),

          // --- SECTION 3: APPEARANCE ---
          Text(
            context.loc.appearance,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),

          // Font Size Slider with Value Display
          Text(context.loc.fontSize),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: fontSize,
                  min: 12,
                  max: 30,
                  onChanged: (value) {
                    setState(() => fontSize = value);
                  },
                  onChangeEnd: (value) => _updateDbPrefs(),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                fontSize.toStringAsFixed(0),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // Opacity Slider with Value Display
          Text(context.loc.backgroundOpacity),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: opacity.toDouble(),
                  min: 20, // Min opacity 20%
                  max: 100, // Max opacity 100%
                  divisions: 16,
                  onChanged: (value) {
                    setState(() => opacity = value.toInt());
                  },
                  onChangeEnd: (value) => _updateDbPrefs(),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "$opacity%",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // Text Color Picker
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.loc.textColor),
            trailing: DropdownButton<String>(
              value: textColorHex,
              items: colorOptions.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.value,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        color: _hexToColor(entry.value),
                        margin: const EdgeInsets.only(right: 8),
                      ),
                      Text(entry.key),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => textColorHex = value);
                  _updateDbPrefs();
                }
              },
            ),
          ),

          // Background Color Picker
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.loc.backgroundColor),
            trailing: DropdownButton<String>(
              value: bgColorHex,
              items: colorOptions.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.value,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        color: _hexToColor(entry.value),
                        margin: const EdgeInsets.only(right: 8),
                      ),
                      Text(entry.key),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => bgColorHex = value);
                  _updateDbPrefs();
                }
              },
            ),
          ),
          const Divider(height: 30),

          // --- SECTION 4: GENERAL SETTINGS ---
          Text(
            context.loc.generalSettings,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),

          // App Display Language
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.loc.appDisplayLanguage),
            trailing: DropdownButton<String>(
              value: appLanguage,
              items: ["English", "Malay", "Chinese"].map((String lang) {
                return DropdownMenuItem<String>(
                  value: lang,
                  child: Text(lang),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => appLanguage = value);
                  _updateSharedPrefs();

                  context.read<SettingsController>().setLanguage(value);
                }
              },
            ),
          ),

          // Dark Mode
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.loc.darkMode),
            value: darkMode,
            onChanged: (value) {
              setState(() => darkMode = value);
              _updateSharedPrefs();

              context.read<SettingsController>().setDarkMode(value);
            },
          ),
        ],
      ),
    );
  }
}