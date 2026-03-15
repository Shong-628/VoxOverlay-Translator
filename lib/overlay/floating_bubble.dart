// floating_bubble.dart
import 'dart:math' as math;
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateWindowSize();
    });
  }

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
    // CRITICAL: Prevent missing widget crashes by ensuring the UI is still active
    if (!mounted) return;

    try {
      if (expanded) {
        await FlutterOverlayWindow.resizeOverlay(280, 280, true);
      } else if (widget.text.trim().isNotEmpty) {
        await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, 160, true);
      } else {
        await FlutterOverlayWindow.resizeOverlay(100, 100, true);
      }
    } catch (e) {
      debugPrint("Resize overlay failed: $e");
    }
  }

  void _handleAction(String action) async {
    FlutterOverlayWindow.shareData({"action": action});

    switch (action) {
      case 'close':
        FlutterOverlayWindow.closeOverlay();
        return;
      case 'settings':
        // wait for listener from main
        return;
      case 'toggle':
        setState(() => isPlaying = !isPlaying);
        break;
    }

    _collapseMenu();
  }

  void _toggleMenu() {
    if (expanded) {
      _collapseMenu();
    } else {
      _expandMenu();
    }
  }

  void _expandMenu() {
    setState(() => expanded = true);
    _updateWindowSize();
  }

  void _collapseMenu() {
    setState(() => expanded = false);
    // Removed the animation delay so the state syncs instantly with the window resize
    if (mounted) {
      _updateWindowSize();
    }
  }

  Widget _getCenterWidget() {
    if (expanded) {
      return const Icon(Icons.close, color: Colors.white, size: 28, key: ValueKey('close_icon'));
    }

    // Using the image asset when collapsed
    return Image.asset(
      'assets/icon/icon.png',
      width: 28,
      height: 28,
      key: const ValueKey('app_icon'),
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.mic, color: Colors.white, size: 28), // Fallback if image fails
    );
  }

  @override
  Widget build(BuildContext context) {
    // FIX 1: Bypass the buggy MediaQuery and get the raw, instant hardware screen metrics
    final view = View.of(context);
    final logicalWidth = view.display.size.width / view.display.devicePixelRatio;

    // Safely calculate max width (half the screen, minus the bubble, with a hard minimum)
    final double safeMaxWidth = math.max(150.0, (logicalWidth / 2) - bubbleRadius - 20);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // FIX 2: Use Center instead of SizedBox.expand. This forces the Stack
      // to shrink exactly to the size of the bubble (60x60).
      body: Center(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ..._buildRadialMenu(),

            if (!expanded && widget.text.trim().isNotEmpty)
              Positioned(
                // Because the Stack is 60x60, 'left' is measured from the left edge of the bubble.
                // 60 (bubble diameter) + 15 (padding) anchors the text perfectly to the right!
                left: (bubbleRadius * 2) + 15,
                child: IgnorePointer(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: safeMaxWidth),
                    child: AnimatedSubtitle(
                      text: widget.text,
                      prefs: widget.prefs,
                    ),
                  ),
                ),
              ),

            GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                width: bubbleRadius * 2,
                height: bubbleRadius * 2,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                ),
                child: Center(
                  child: _getCenterWidget(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRadialMenu() {
    // If not expanded, don't build or render the buttons at all
    if (!expanded) return [];

    final actions = [
      {'icon': Icons.settings, 'label': 'settings'},
      {'icon': isPlaying ? Icons.pause : Icons.play_arrow, 'label': 'toggle'},
      {'icon': Icons.power_settings_new, 'label': 'close'},
    ];

    // Adjusted for 3 buttons instead of 4 so they spread out properly
    final angles = [-math.pi / 2, -math.pi / 4, 0.0];

    // FIX: Use actions.length to prevent the RangeError crash
    return List.generate(actions.length, (index) {
      double dx = menuRadius * math.cos(angles[index]);
      double dy = menuRadius * math.sin(angles[index]);

      return Transform.translate(
        offset: Offset(dx, dy),
        child: IconButton.filled(
          onPressed: () => _handleAction(actions[index]['label'] as String),
          icon: Icon(actions[index]['icon'] as IconData, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            padding: const EdgeInsets.all(12),
          ),
        ),
      );
    });
  }
}