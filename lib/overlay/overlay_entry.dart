import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'floating_bubble.dart';

@pragma("vm:entry-point")
void overlayMain() {
  runApp(const OverlayApp());
}

class OverlayApp extends StatelessWidget {
  const OverlayApp({super.key});

  @override
  Widget build(BuildContext context) {

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayScreen(),
    );
  }
}

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {

  String subtitle = "Listening...";

  @override
  void initState() {
    super.initState();

    FlutterOverlayWindow.overlayListener.listen((data) {

      setState(() {
        subtitle = data;
      });

    });
  }

  @override
  Widget build(BuildContext context) {

    return Material(
      color: Colors.transparent,
      child: Center(
        child: FloatingBubble(text: subtitle),
      ),
    );
  }
}