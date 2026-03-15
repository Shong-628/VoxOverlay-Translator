// floating_bubble.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
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

  // FIX: Added a resize lock and queue to handle rapid text streaming
  bool _isResizing = false;
  bool _resizeQueued = false;

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

    // CRITICAL FIX: Trigger resize on text change, but ONLY if not expanded.
    // If expanded, the subtitles are hidden, so we don't need to resize.
    // This also prevents the "resizing lock" from making the menu unresponsive during text streaming.
    if (oldWidget.text != widget.text && !expanded) {
      _updateWindowSize();
    }
  }

  /// Dynamically measures the exact pixel height needed for the text
  int _calculateDynamicHeight(BuildContext? context) {
    if (expanded) return 280;
    if (widget.text.trim().isEmpty) return 100;

    // Safely get logical width using display size for consistent screen-relative measurements
    final view = context != null ? View.of(context) : ui.PlatformDispatcher.instance.views.first;
    final logicalWidth = view.display.size.width / view.display.devicePixelRatio;
    final double safeMaxWidth = math.max(150.0, logicalWidth - 40);

    // Simulate drawing the text to get its exact height
    final span = TextSpan(
      text: widget.text,
      style: TextStyle(fontSize: widget.prefs.fontSizeScale),
    );

    final tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Layout the text within our safe bounds minus horizontal padding (12 * 2 = 24)
    tp.layout(maxWidth: safeMaxWidth - 24);

    // Base Stack (100) + Top Padding (10) + Vertical Text Padding (12) + Text Height + Bottom Padding (15)
    final totalHeight = 100.0 + 10.0 + 12.0 + tp.size.height + 15.0;

    return totalHeight.ceil();
  }

  Future<void> _updateWindowSize() async {
    // CRITICAL: Prevent missing widget crashes by ensuring the UI is still active
    if (!mounted) return;

    // If already resizing, queue the request so we don't drop frame updates during streaming
    if (_isResizing) {
      _resizeQueued = true;
      return;
    }

    _isResizing = true;

    try {
      if (expanded) {
        await FlutterOverlayWindow.resizeOverlay(280, 280, true);
      } else if (widget.text.trim().isNotEmpty) {
        // Feed the perfectly calculated height directly to the Android window
        int dynHeight = _calculateDynamicHeight(context);
        await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, dynHeight, true);
      } else {
        await FlutterOverlayWindow.resizeOverlay(100, 100, true);
      }
    } catch (e) {
      debugPrint("Resize overlay failed: $e");
    } finally {
      if (mounted) {
        _isResizing = false;
        // Process the queue if text changed rapidly while we were resizing
        if (_resizeQueued) {
          _resizeQueued = false;
          _updateWindowSize();
        }
      }
    }
  }

  void _handleAction(String action) async {
    debugPrint("Overlay action: $action");
    FlutterOverlayWindow.shareData({"action": action});

    switch (action) {
      case 'close':
        FlutterOverlayWindow.closeOverlay();
        return;
      case 'settings':
        _collapseMenu();
        return;
      case 'toggle':
        setState(() {
          isPlaying = !isPlaying;
          expanded = false;
        });
        if (mounted) _updateWindowSize();
        return;
    }

    _collapseMenu();
  }

  void _toggleMenu() {
    // Allow toggling even if resizing is queued, but skip if currently in the middle of a resize call
    if (_isResizing) return;

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
    if (mounted) {
      _updateWindowSize();
    }
  }

  Widget _getCenterWidget() {
    if (expanded) {
      return const Icon(Icons.close, color: Colors.white, size: 28, key: ValueKey('close_icon'));
    }

    return Image.asset(
      'assets/icon/icon.png',
      width: 28,
      height: 28,
      key: const ValueKey('app_icon'),
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.mic, color: Colors.white, size: 28),
    );
  }

  Color _hexToColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final logicalWidth = view.display.size.width / view.display.devicePixelRatio;
    final double safeMaxWidth = math.max(150.0, logicalWidth - 40);

    final double currentWidth = expanded ? 280.0 : (widget.text.trim().isNotEmpty ? logicalWidth : 100.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox(
        width: currentWidth,
        child: Align(
          alignment: Alignment.topCenter,
          // FIX: Wrap Column in SingleChildScrollView with NeverScrollableScrollPhysics.
          // This suppresses "RenderFlex overflow" errors during the split-second
          // when the widget has updated its size but the Android window hasn't resized yet.
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // MAIN BUBBLE & RADIAL MENU
                SizedBox(
                  width: expanded ? 280.0 : 100.0,
                  height: expanded ? 280.0 : 100.0,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      ..._buildRadialMenu(),
                      GestureDetector(
                        onTap: _toggleMenu,
                        child: Container(
                          width: bubbleRadius * 2,
                          height: bubbleRadius * 2,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.9),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: Center(
                            child: _getCenterWidget(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // SUBTITLE DISPLAY
                if (!expanded && widget.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 15),
                    child: IgnorePointer(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: safeMaxWidth),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _hexToColor(widget.prefs.bgColorHex).withOpacity(widget.prefs.overlayOpacity / 100.0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _hexToColor(widget.prefs.textColorHex),
                            fontSize: widget.prefs.fontSizeScale,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRadialMenu() {
    final actions = <({IconData icon, String label})>[
      (icon: Icons.settings, label: 'settings'),
      (icon: isPlaying ? Icons.pause : Icons.play_arrow, label: 'toggle'),
      (icon: Icons.power_settings_new, label: 'close'),
    ];

    final angles = [-math.pi / 2, -math.pi / 4, 0.0];

    return List.generate(actions.length, (index) {
      double dx = menuRadius * math.cos(angles[index]);
      double dy = menuRadius * math.sin(angles[index]);

      return Transform.translate(
        offset: Offset(dx, dy),
        child: AnimatedScale(
          scale: expanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: expanded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: IconButton.filled(
              onPressed: expanded ? () => _handleAction(actions[index].label) : null,
              icon: Icon(actions[index].icon, color: Colors.white),
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
