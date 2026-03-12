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
  bool isPlaying = true;
  bool isDragging = false;

  // Tracks the absolute center position of the bubble on screen
  Offset? position;

  void _handleAction(String action) {
    FlutterOverlayWindow.shareData({"action": action});
    if (action == 'close') FlutterOverlayWindow.closeOverlay();
    if (action == 'toggle') setState(() => isPlaying = !isPlaying);
    setState(() => expanded = false);
  }

  /// Calculates safe angles for the menu buttons based on screen edges
  List<double> get _dynamicAngles {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    if (position == null) return [-pi / 2, 0, pi / 2, pi]; // Fallback

    final double px = position!.dx;
    final double py = position!.dy;
    final double menuRadius = 130.0; // Button distance + safety buffer

    bool nearLeft = px < menuRadius;
    bool nearRight = screenWidth - px < menuRadius;
    bool nearTop = py < menuRadius;
    bool nearBottom = screenHeight - py < menuRadius;

    double startA = 0;
    double endA = 2 * pi;

    // Corner cases
    if (nearLeft && nearTop) { startA = 0; endA = pi / 2; }
    else if (nearRight && nearTop) { startA = pi / 2; endA = pi; }
    else if (nearRight && nearBottom) { startA = pi; endA = 3 * pi / 2; }
    else if (nearLeft && nearBottom) { startA = 3 * pi / 2; endA = 2 * pi; }
    // Edge cases
    else if (nearLeft) { startA = -pi / 2; endA = pi / 2; }
    else if (nearRight) { startA = pi / 2; endA = 3 * pi / 2; }
    else if (nearTop) { startA = 0; endA = pi; }
    else if (nearBottom) { startA = -pi; endA = 0; }
    // Center safe zone (Standard Cross)
    else { return [-pi / 2, 0, pi / 2, pi]; }

    // Distribute 4 buttons evenly within the safe angle range
    List<double> angles = [];
    double step = (endA - startA) / 3;
    for (int i = 0; i < 4; i++) {
      angles.add(startA + (step * i));
    }
    return angles;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Initialize position at the bottom center of the screen
    position ??= Offset(screenWidth / 2, screenHeight - 150);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Render Radial Buttons behind the main bubble
            ..._buildDynamicMenuButtons(),

            // Main Bubble / Text Card
            AnimatedPositioned(
              duration: isDragging ? Duration.zero : const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              // When collapsed, anchor 20px from left. When expanded, center around the coordinates.
              left: expanded ? position!.dx - 40 : 20,
              top: expanded ? position!.dy - 40 : position!.dy - 30,
              child: GestureDetector(
                onPanStart: (_) => setState(() => isDragging = true),
                onPanEnd: (_) => setState(() => isDragging = false),
                onPanUpdate: (details) {
                  setState(() {
                    position = Offset(
                      (position!.dx + details.delta.dx).clamp(40.0, screenWidth - 40.0),
                      (position!.dy + details.delta.dy).clamp(40.0, screenHeight - 40.0),
                    );
                  });
                },
                onLongPress: () => setState(() => expanded = !expanded),
                onTap: () { if (expanded) setState(() => expanded = false); },

                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(minHeight: 60),
                  // Spans 100% of available screen width minus margins when collapsed
                  width: expanded ? 80 : screenWidth - 40,
                  height: expanded ? 80 : null, // null allows it to auto-expand vertically for long text
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(expanded ? 40 : 15),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: expanded
                      ? const Icon(Icons.translate, color: Colors.white, size: 30)
                      : AnimatedSubtitle(text: widget.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDynamicMenuButtons() {
    final angles = _dynamicAngles;
    final actions = [
      {'icon': Icons.settings, 'label': 'settings'},
      {'icon': isPlaying ? Icons.pause : Icons.play_arrow, 'label': 'toggle'},
      {'icon': Icons.power_settings_new, 'label': 'close'},
      {'icon': Icons.close, 'label': 'minimize'},
    ];

    return List.generate(4, (index) {
      return _buildMenuButton(
        actions[index]['icon'] as IconData,
        angles[index],
        actions[index]['label'] as String,
      );
    });
  }

  Widget _buildMenuButton(IconData icon, double angle, String label) {
    double distance = expanded ? 110.0 : 0.0;

    // Calculate the absolute position on the screen
    double dx = position!.dx + (distance * cos(angle));
    double dy = position!.dy + (distance * sin(angle));

    return AnimatedPositioned(
      duration: isDragging ? Duration.zero : const Duration(milliseconds: 400),
      curve: isDragging ? Curves.linear : Curves.elasticOut,
      left: dx - 24, // 24 is half of standard IconButton size (48) to perfectly center it
      top: dy - 24,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: expanded ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !expanded,
          child: IconButton.filled(
            onPressed: () => _handleAction(label),
            icon: Icon(icon),
            style: IconButton.styleFrom(backgroundColor: Colors.deepPurple),
          ),
        ),
      ),
    );
  }
}