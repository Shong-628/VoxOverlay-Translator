// floating_bubble.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'animated_subtitle.dart';

class FloatingBubble extends StatefulWidget {
  final String text;
  const FloatingBubble({super.key, required this.text});

  @override
  State<FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<FloatingBubble> {
  bool expanded = false;
  bool isPlaying = true; // State for Play/Pause toggle

  void _handleAction(String action) {
    // Send the action back to the main app
    FlutterOverlayWindow.shareData({"action": action});

    if (action == 'close') {
      FlutterOverlayWindow.closeOverlay();
    } else if (action == 'toggle') {
      setState(() => isPlaying = !isPlaying);
    }

    setState(() => expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // The Radial Buttons (Only visible when expanded)
        if (expanded) ...[
          _buildMenuButton(icon: isPlaying ? Icons.pause : Icons.play_arrow, angle: -pi / 2, label: 'toggle'), // Top
          _buildMenuButton(icon: Icons.settings, angle: 0, label: 'settings'),                               // Right
          _buildMenuButton(icon: Icons.power_settings_new, angle: pi / 2, label: 'close'),                  // Bottom
          _buildMenuButton(icon: Icons.history, angle: pi, label: 'history'),                                // Left (Example 4th button)
        ],

        // The Subtitle / App Icon Bubble
        GestureDetector(
          onTap: () => setState(() => expanded = !expanded),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: expanded ? 80 : (widget.text.length > 20 ? 300 : 80),
            height: 80,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(200),
              shape: BoxShape.circle,
              image: expanded ? null : const DecorationImage(
                image: AssetImage('assets/icon/app_icon.png'), // Your App Icon
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)
              ],
            ),
            child: (!expanded && widget.text != "Listening...")
                ? Center(child: AnimatedSubtitle(text: widget.text))
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButton({required IconData icon, required double angle, required String label}) {
    double distance = 90.0; // How far buttons move out
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      transform: Matrix4.translationValues(
        expanded ? distance * cos(angle) : 0,
        expanded ? distance * sin(angle) : 0,
        0,
      ),
      child: GestureDetector(
        onTap: () => _handleAction(label),
        child: CircleAvatar(
          backgroundColor: Colors.deepPurple,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}