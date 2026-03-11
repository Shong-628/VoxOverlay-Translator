import 'package:flutter/material.dart';
// import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() {
  runApp(const VoxOverlayApp());
}

class VoxOverlayApp extends StatelessWidget {
  const VoxOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoxOverlay Translator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const OnboardingScreen(),
    );
  }
}

