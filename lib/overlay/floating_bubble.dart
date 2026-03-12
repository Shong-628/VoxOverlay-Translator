// floating_bubble.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'animated_subtitle.dart';
import '../models/user_preference.dart';

class FloatingBubble extends StatefulWidget {
  final String text;
  final UserPreference prefs; // Accept preferences from parent

  const FloatingBubble({
    super.key,
    required this.text,
    required this.prefs,
  });

  @override
  State<FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<FloatingBubble> {
  bool expanded = false;
  bool isPlaying = true;
  bool isDragging = false;

  Offset? position;
  final double bubbleRadius = 30.0; // Fixed radius for the drag handle

  void _handleAction(String action) {
    FlutterOverlayWindow.shareData({"action": action});
    if (action == 'close') FlutterOverlayWindow.closeOverlay();
    if (action == 'toggle') setState(() => isPlaying = !isPlaying);
    setState(() => expanded = false);
  }

  List<double> get _dynamicAngles {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    if (position == null) return [-pi / 2, 0, pi / 2, pi];

    final double px = position!.dx;
    final double py = position!.dy;
    final double menuRadius = 130.0;

    bool nearLeft = px < menuRadius;
    bool nearRight = screenWidth - px < menuRadius;
    bool nearTop = py < menuRadius;
    bool nearBottom = screenHeight - py < menuRadius;

    double startA = 0;
    double endA = 2 * pi;

    if (nearLeft && nearTop) { startA = 0; endA = pi / 2; }
    else if (nearRight && nearTop) { startA = pi / 2; endA = pi; }
    else if (nearRight && nearBottom) { startA = pi; endA = 3 * pi / 2; }
    else if (nearLeft && nearBottom) { startA = 3 * pi / 2; endA = 2 * pi; }
    else if (nearLeft) { startA = -pi / 2; endA = pi / 2; }
    else if (nearRight) { startA = pi / 2; endA = 3 * pi / 2; }
    else if (nearTop) { startA = 0; endA = pi; }
    else if (nearBottom) { startA = -pi; endA = 0; }
    else { return [-pi / 2, 0, pi / 2, pi]; }

    List<double> angles = [];
    double step = (endA - startA) / 3;
    for (int i = 0; i < 4; i++) {
      angles.add(startA + (step * i));
    }
    return angles;
  }

  // Determines which icon should appear in the center bubble
  IconData _getCenterIcon() {
    if (expanded) return Icons.close;
    return isPlaying ? Icons.translate : Icons.pause;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    position ??= Offset(screenWidth / 2, screenHeight - 150);

    // Determines if we have more space on the left side of the screen
    final bool showSubtitleOnLeft = position!.dx > (screenWidth / 2);
    final double spacing = 12.0; // Space between bubble and subtitle

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Menu Buttons
            ..._buildDynamicMenuButtons(),

            // 2. The dynamic Subtitle Box
            AnimatedPositioned(
              duration: isDragging ? Duration.zero : const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              top: position!.dy, // Anchored to the vertical center of the bubble

              // Anchor logic based on available space
              left: showSubtitleOnLeft ? null : position!.dx + bubbleRadius + spacing,
              right: showSubtitleOnLeft ? screenWidth - position!.dx + bubbleRadius + spacing : null,

              child: FractionalTranslation(
                translation: const Offset(0, -0.5), // Perfectly centers it vertically against the top anchor
                child: Container(
                  constraints: BoxConstraints(
                    // Dynamically limit max width so it forces a text wrap before hitting the screen edge
                    maxWidth: showSubtitleOnLeft
                        ? (position!.dx - bubbleRadius - spacing - 16).clamp(0.0, double.infinity)
                        : (screenWidth - position!.dx - bubbleRadius - spacing - 16).clamp(0.0, double.infinity),
                  ),
                  child: expanded
                      ? const SizedBox.shrink() // Hide subtitles when menu is open
                      : AnimatedSubtitle(
                    text: widget.text,
                    prefs: widget.prefs,
                  ),
                ),
              ),
            ),

            // 3. The Core Drag Bubble
            AnimatedPositioned(
              duration: isDragging ? Duration.zero : const Duration(milliseconds: 150),
              left: position!.dx - bubbleRadius,
              top: position!.dy - bubbleRadius,
              child: GestureDetector(
                onPanStart: (_) => setState(() => isDragging = true),
                onPanEnd: (_) => setState(() => isDragging = false),
                onPanUpdate: (details) {
                  setState(() {
                    position = Offset(
                      (position!.dx + details.delta.dx).clamp(bubbleRadius + 10, screenWidth - bubbleRadius - 10),
                      (position!.dy + details.delta.dy).clamp(bubbleRadius + 10, screenHeight - bubbleRadius - 10),
                    );
                  });
                },
                onLongPress: () => setState(() => expanded = !expanded),
                onTap: () { if (expanded) setState(() => expanded = false); },

                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: bubbleRadius * 2,
                  height: bubbleRadius * 2,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, animation) {
                        final rotate = Tween<double>(begin: 0.8, end: 1).animate(animation);
                        return RotationTransition(
                          turns: rotate,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        _getCenterIcon(),
                        key: ValueKey(_getCenterIcon()),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
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
      {'icon': Icons.compress, 'label': 'minimize'},
    ];

    return List.generate(4, (index) {
      return _buildMenuButton(
        actions[index]['icon'] as IconData,
        angles[index],
        actions[index]['label'] as String,
        index,
      );
    });
  }

  Widget _buildMenuButton(IconData icon, double angle, String label, int index) {
    double distance = expanded ? 90.0 : 0.0;

    double dx = position!.dx + (distance * cos(angle));
    double dy = position!.dy + (distance * sin(angle));

    return AnimatedPositioned(
      duration: isDragging ? Duration.zero : const Duration(milliseconds: 350),
      curve: isDragging ? Curves.linear : Curves.elasticOut,
      left: dx - 24,
      top: dy - 24,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 150 + (index * 60)), // iOS-style stagger
        opacity: expanded ? 1.0 : 0.0,
        child: AnimatedScale(
          scale: expanded ? 1.0 : 0.4,
          duration: Duration(milliseconds: 180 + (index * 60)), // stagger pop
          curve: Curves.easeOutBack,
          child: IgnorePointer(
            ignoring: !expanded,
            child: IconButton.filled(
              onPressed: () => _handleAction(label),
              icon: Icon(icon, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shadowColor: Colors.black,
                elevation: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}