// floating_bubble.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'animated_subtitle.dart';
import '../models/user_preference.dart';

class FloatingBubble extends StatefulWidget {
  final String text;
  final UserPreference prefs;

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

  final double bubbleRadius = 30.0;
  final double menuRadius = 80.0;

  @override
  void didUpdateWidget(FloatingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool wasEmpty = oldWidget.text.trim().isEmpty;
    bool isEmpty = widget.text.trim().isEmpty;

    if (wasEmpty != isEmpty) {
      _updateWindowSize();
    }
  }

  Future<void> _updateWindowSize() async {
    if (expanded) {
      await FlutterOverlayWindow.resizeOverlay(280, 280, true);
    } else if (widget.text.trim().isNotEmpty) {
      await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, 160, true);
    } else {
      await FlutterOverlayWindow.resizeOverlay(100, 100, true);
    }
  }

  void _handleAction(String action) async {
    FlutterOverlayWindow.shareData({"action": action});

    if (action == 'close') {
      FlutterOverlayWindow.closeOverlay();
      return;
    }

    if (action == 'toggle') setState(() => isPlaying = !isPlaying);

    _collapseMenu();
  }

  // --- NEW MENU LOGIC WITH ANIMATION TIMING ---
  void _toggleMenu() {
    if (expanded) {
      _collapseMenu();
    } else {
      _expandMenu();
    }
  }

  void _expandMenu() {
    setState(() => expanded = true);
    // Expand window instantly so the outward animation has room to show
    _updateWindowSize();
  }

  void _collapseMenu() async {
    setState(() => expanded = false);
    // Wait for the buttons to animate back to the center BEFORE shrinking the window
    await Future.delayed(const Duration(milliseconds: 300));
    // Only shrink if the user hasn't re-opened the menu during the wait
    if (!expanded && mounted) {
      _updateWindowSize();
    }
  }

  IconData _getCenterIcon() {
    if (expanded) return Icons.close;
    return isPlaying ? Icons.translate : Icons.pause;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // FIX 1: SizedBox.expand forces the Stack to fill the entire Android Window size.
      // This guarantees your expanded buttons will be inside the bounds and clickable.
      body: SizedBox.expand(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ..._buildRadialMenu(),

            if (!expanded && widget.text.trim().isNotEmpty)
              Transform.translate(
                offset: const Offset(120, 0),
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: AnimatedSubtitle(
                      text: widget.text,
                      prefs: widget.prefs,
                    ),
                  ),
                ),
              ),

            GestureDetector(
              // FIX 2: Replaced onLongPress with onTap
              onTap: _toggleMenu,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: bubbleRadius * 2,
                height: bubbleRadius * 2,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
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
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRadialMenu() {
    final actions = [
      {'icon': Icons.settings, 'label': 'settings'},
      {'icon': isPlaying ? Icons.pause : Icons.play_arrow, 'label': 'toggle'},
      {'icon': Icons.power_settings_new, 'label': 'close'},
      {'icon': Icons.compress, 'label': 'minimize'},
    ];

    final angles = [-pi / 2, 0.0, pi / 2, pi];

    return List.generate(4, (index) {
      double distance = expanded ? menuRadius : 0.0;
      double dx = distance * cos(angles[index]);
      double dy = distance * sin(angles[index]);

      // FIX 4: Determine rotation. Spins from -180 degrees (-pi) to 0 (upright).
      double rotation = expanded ? 0.0 : -pi;

      // FIX 3: Replaced Transform.translate with AnimatedContainer(transform: ...)
      return AnimatedContainer(
        // Add a slight stagger so the buttons fan out nicely
        duration: Duration(milliseconds: 200 + (index * 40)),
        curve: Curves.easeOutBack, // Gives a great physical "pop" and bounce
        // We use the cascade operator (..) to apply rotation directly after translation
        transform: Matrix4.translationValues(dx, dy, 0)..rotateZ(rotation),
        // Ensure it rotates from the center of the button, not the top-left corner
        alignment: Alignment.center,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: expanded ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !expanded,
            child: IconButton.filled(
              onPressed: () => _handleAction(actions[index]['label'] as String),
              icon: Icon(actions[index]['icon'] as IconData, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ),
      );
    });
  }
}