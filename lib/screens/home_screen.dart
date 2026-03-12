// home_screen.dart
import 'package:flutter/material.dart';
import '../overlay/overlay_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> startOverlay(BuildContext context) async {
    try {
      // Check if overlay permission is granted
      bool hasPermission = await OverlayService.hasPermission();

      if (!hasPermission) {
        // Request permission
        await OverlayService.requestPermission();

        // Check again after requesting
        hasPermission = await OverlayService.hasPermission();

        if (!hasPermission) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Overlay permission is required."),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      // Start overlay
      await OverlayService.startOverlay();

    } catch (e) {
      debugPrint("Overlay start error: $e");

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to start overlay: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("VoxOverlay Translator"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          )
        ],
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await startOverlay(context);
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 60,
              vertical: 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(40),
            ),
          ),
          child: const Text(
            "Start Translation",
            style: TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }
}