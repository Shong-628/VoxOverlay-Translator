import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {

  String selected = "English";

  final languages = [
    "English",
    "Chinese",
    "Malay"
  ];

  void select(String language) {

    setState(() {
      selected = language;
    });

    Fluttertoast.showToast(
      msg: "Language set to $language",
    );

    Future.delayed(
      const Duration(milliseconds: 500),
          () {
        Navigator.pop(context, language);
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Language"),
      ),

      body: ListView.builder(
        itemCount: languages.length,
        itemBuilder: (context, index) {

          final language = languages[index];

          return RadioListTile(
            title: Text(language),
            value: language,
            groupValue: selected,
            onChanged: (value) {
              select(value!);
            },
          );
        },
      ),
    );
  }
}