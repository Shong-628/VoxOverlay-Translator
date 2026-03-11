import 'package:flutter/material.dart';
import 'language_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  double fontSize = 18;
  double opacity = 0.6;
  bool darkMode = true;

  String language = "English";

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          const Text(
            "Translation",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 10),

          ListTile(
            title: const Text("Target Language"),
            subtitle: Text(language),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LanguageSelectionScreen(),
                ),
              );

              if (result != null) {
                setState(() {
                  language = result;
                });
              }
            },
          ),

          const SizedBox(height: 20),

          const Text(
            "Appearance",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 10),

          const Text("Font Size"),

          Slider(
            value: fontSize,
            min: 12,
            max: 30,
            onChanged: (value) {
              setState(() {
                fontSize = value;
              });
            },
          ),

          const Text("Background Opacity"),

          Slider(
            value: opacity,
            min: 0.2,
            max: 1,
            onChanged: (value) {
              setState(() {
                opacity = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text("Dark Mode"),
            value: darkMode,
            onChanged: (value) {
              setState(() {
                darkMode = value;
              });
            },
          ),

          const SizedBox(height: 20),

          const Text(
            "Support",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),

          const ListTile(
            title: Text("About"),
          )
        ],
      ),
    );
  }
}