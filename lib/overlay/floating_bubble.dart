// floating_bubble.dart
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../models/user_preference.dart';

// --- Extensions ---
extension ColorExtension on String {
  Color toColor() {
    try {
      final buffer = StringBuffer();
      if (length == 6 || length == 7) buffer.write('ff');
      buffer.write(replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return Colors.black; // Fallback color
    }
  }
}

// --- Constants ---
const double _kCollapsedSize = 100.0;
const double _kExpandedSize = 280.0;
const double _kBubbleRadius = 30.0;
const double _kMenuRadius = 80.0;
const String _kActionPrefix = "ACTION_PREFIX:";

// --- Widget ---
class FloatingBubble extends StatefulWidget {
  final String text;
  final UserPreference prefs;
  final bool isRunning;
  final bool isPaused;

  const FloatingBubble({
    super.key,
    required this.text,
    required this.prefs,
    required this.isRunning,
    required this.isPaused,
  });

  @override
  State<FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<FloatingBubble> {
  bool _expanded = false;
  bool _isResizing = false;
  bool _resizeQueued = false;
  int _lastCalculatedHeight = 0;

  late bool _isLocallyPlaying;

  @override
  void initState() {
    super.initState();
    _isLocallyPlaying = widget.isRunning && !widget.isPaused;

    // FIX: Delay the initial resize by 150ms to ensure Android WindowManager
    // has actually attached the surface. Fixes the "half circle" restart bug.
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _updateWindowSize(force: true);
    });
  }

  @override
  void didUpdateWidget(FloatingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isRunning != widget.isRunning || oldWidget.isPaused != widget.isPaused) {
      _isLocallyPlaying = widget.isRunning && !widget.isPaused;
    }

    if ((oldWidget.text != widget.text || oldWidget.isRunning != widget.isRunning) && !_expanded) {
      _updateWindowSize();
    }
  }

  int _calculateDynamicHeight(BuildContext? context) {
    if (_expanded) return _kExpandedSize.toInt();
    if (widget.text.trim().isEmpty) return _kCollapsedSize.toInt();

    final view = context != null ? View.of(context) : ui.PlatformDispatcher.instance.views.first;
    final logicalWidth = view.display.size.width / view.display.devicePixelRatio;
    final double safeMaxWidth = math.max(150.0, logicalWidth - 40);

    final span = TextSpan(
      text: widget.text,
      style: TextStyle(fontSize: widget.prefs.fontSizeScale),
    );

    final textPainter = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: safeMaxWidth - 24);

    final totalHeight = _kCollapsedSize + 10.0 + 12.0 + textPainter.size.height + 15.0;
    return totalHeight.ceil();
  }

  // Added 'force' parameter to bypass cache on boot
  Future<void> _updateWindowSize({bool force = false}) async {
    if (!mounted) return;

    int targetHeight;
    if (_expanded) {
      targetHeight = _kExpandedSize.toInt();
    } else if (widget.text.trim().isNotEmpty) {
      targetHeight = _calculateDynamicHeight(context);
    } else {
      targetHeight = _kCollapsedSize.toInt();
    }

    if (!force && targetHeight == _lastCalculatedHeight && !_expanded) {
      return;
    }

    if (_isResizing) {
      _resizeQueued = true;
      return;
    }

    _isResizing = true;
    _lastCalculatedHeight = targetHeight;

    try {
      if (_expanded) {
        await FlutterOverlayWindow.resizeOverlay(_kExpandedSize.toInt(), _kExpandedSize.toInt(), true);
      } else if (widget.text.trim().isNotEmpty) {
        await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, targetHeight, true);
      } else {
        await FlutterOverlayWindow.resizeOverlay(_kCollapsedSize.toInt(), _kCollapsedSize.toInt(), true);
      }
    } catch (e) {
      debugPrint("Resize overlay failed: $e");
    } finally {
      if (mounted) {
        _isResizing = false;
        if (_resizeQueued) {
          _resizeQueued = false;
          _updateWindowSize();
        }
      }
    }
  }

  void _handleAction(String action) {
    debugPrint("Overlay action sent: $action");

    final payload = "$_kActionPrefix$action";

    // 1. Direct Memory Isolate Port (Bulletproof)
    final SendPort? sendPort = ui.IsolateNameServer.lookupPortByName('vox_overlay_port');
    sendPort?.send(payload);

    // 2. Fallback channel just in case
    FlutterOverlayWindow.shareData(payload);

    if (action == 'close' || action == 'settings') {
      _collapseMenu();
    } else if (action == 'toggle') {
      setState(() => _isLocallyPlaying = !_isLocallyPlaying);
      _collapseMenu();
    }
  }

  void _toggleMenu() {
    if (_isResizing) return;
    _expanded ? _collapseMenu() : _expandMenu();
  }

  void _expandMenu() {
    setState(() => _expanded = true);
    _updateWindowSize(force: true); // Force layout bounds update
  }

  void _collapseMenu() {
    setState(() => _expanded = false);
    if (mounted) _updateWindowSize(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final logicalWidth = view.display.size.width / view.display.devicePixelRatio;
    final safeMaxWidth = math.max(150.0, logicalWidth - 40);
    final currentWidth = _expanded ? _kExpandedSize : (widget.text.trim().isNotEmpty ? logicalWidth : _kCollapsedSize);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox(
        width: currentWidth,
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMainBubbleAndMenu(),
                if (!_expanded && widget.text.trim().isNotEmpty)
                  _buildSubtitleBox(safeMaxWidth),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainBubbleAndMenu() {
    final double size = _expanded ? _kExpandedSize : _kCollapsedSize;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ..._buildRadialMenu(),
          GestureDetector(
            onTap: _toggleMenu,
            child: Container(
              width: _kBubbleRadius * 2,
              height: _kBubbleRadius * 2,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: Center(
                child: _expanded
                    ? const Icon(Icons.close, color: Colors.white, size: 28)
                    : Image.asset(
                  'assets/icon/icon.png',
                  width: 28,
                  height: 28,
                  errorBuilder: (_, __, ___) => const Icon(Icons.mic, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRadialMenu() {
    final actions = [
      (icon: Icons.settings, label: 'settings'),
      (icon: _isLocallyPlaying ? Icons.pause : Icons.play_arrow, label: 'toggle'),
      (icon: Icons.power_settings_new, label: 'close'),
    ];

    final angles = [-math.pi / 2, -math.pi / 4, 0.0];

    return List.generate(actions.length, (index) {
      final dx = _kMenuRadius * math.cos(angles[index]);
      final dy = _kMenuRadius * math.sin(angles[index]);

      return Transform.translate(
        offset: Offset(dx, dy),
        child: AnimatedScale(
          scale: _expanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: _expanded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: IconButton.filled(
              onPressed: _expanded ? () => _handleAction(actions[index].label) : null,
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

  Widget _buildSubtitleBox(double maxWidth) {
    final bgColor = widget.prefs.bgColorHex.toColor();
    final textColor = widget.prefs.textColorHex.toColor();

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 15),
      child: IgnorePointer(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor.withOpacity(widget.prefs.overlayOpacity / 100.0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: widget.prefs.fontSizeScale,
            ),
          ),
        ),
      ),
    );
  }
}