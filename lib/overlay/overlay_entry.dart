// overlay_entry.dart
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'floating_bubble.dart';

// Rename this to something internal or keep it as overlayMain
// as long as main.dart knows where to find it.
void runOverlayApp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayApp(),
  ));
}

class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});
  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  String subtitle = "Listening...";

  @override
  void initState() {
    super.initState();
    // Listen for data from the main app
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data != null) {
        setState(() => subtitle = data.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material( // Use Material or Scaffold with transparent bg
      color: Colors.transparent,
      child: Center(
        child: FloatingBubble(text: subtitle),
      ),
    );
  }
}