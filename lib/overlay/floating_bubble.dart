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
    try {
      if (expanded) {
        await FlutterOverlayWindow.resizeOverlay(280, 280, true);
      } else if (widget.text.trim().isNotEmpty) {
        await FlutterOverlayWindow.resizeOverlay(-1, 160, true);
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
        FlutterOverlayWindow.closeOverlay();
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

  void _collapseMenu() async {
    setState(() => expanded = false);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!expanded && mounted) {
      _updateWindowSize();
    }
  }

  Widget _getCenterWidget() {
    if (expanded) {
      return const Icon(Icons.close, color: Colors.white, size: 28, key: ValueKey('close_icon'));
    }

    // Using the image asset when collapsed
    return Image.asset(
      '../lib/assets/icon.png', // Ensure this matches your pubspec.yaml path exactly
      width: 28,
      height: 28,
      key: const ValueKey('app_icon'),
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.mic, color: Colors.white, size: 28), // Fallback if image fails
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // FIX: Safely calculate max width, ensuring it never drops below 0.0
    final double rawMaxWidth = (screenWidth / 2) - bubbleRadius - 35;
    final double safeMaxWidth = math.max(0.0, rawMaxWidth);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ..._buildRadialMenu(),

            if (!expanded && widget.text.trim().isNotEmpty)
              Positioned(
                left: (screenWidth / 2) + bubbleRadius + 15,
                child: IgnorePointer(
                  child: Container(
                    // Apply the safe math calculation here
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
                    child: _getCenterWidget(),
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
    ];

    // Adjusted for 3 buttons instead of 4 so they spread out properly
    final angles = [-math.pi / 2, -math.pi / 4, 0.0];

    // FIX: Use actions.length to prevent the RangeError crash
    return List.generate(actions.length, (index) {
      double distance = expanded ? menuRadius : 0.0;
      double dx = distance * math.cos(angles[index]);
      double dy = distance * math.sin(angles[index]);

      double rotation = expanded ? 0.0 : -math.pi;

      return AnimatedContainer(
        duration: Duration(milliseconds: 200 + (index * 40)),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(dx, dy, 0)..rotateZ(rotation),
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