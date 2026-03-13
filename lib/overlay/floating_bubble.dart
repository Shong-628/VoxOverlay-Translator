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
    if (expanded) {
      await FlutterOverlayWindow.resizeOverlay(280, 280, true);
    } else if (widget.text.trim().isNotEmpty) {
      // Use matchParent when text is present so we have the full screen width to draw subtitles
      await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, 160, true);
    } else {
      // Shrink to just the bubble size when idle
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

  IconData _getCenterIcon() {
    if (expanded) return Icons.close;
    return isPlaying ? Icons.translate : Icons.pause;
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

    final angles = [-math.pi / 2, 0.0, math.pi / 2, math.pi];

    return List.generate(4, (index) {
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