// animated_subtitle.dart
import 'package:flutter/material.dart';
import '../models/user_preference.dart'; // Ensure you import your model here

class AnimatedSubtitle extends StatelessWidget {
  final String text;
  final UserPreference prefs;

  const AnimatedSubtitle({
    super.key,
    required this.text,
    required this.prefs,
  });

  /// Helper to convert hex strings (e.g., "#000000") to Flutter Colors
  Color _parseColor(String hexColor, [int opacityPercentage = 100]) {
    try {
      final hexCode = hexColor.replaceAll('#', '');
      final colorInt = int.parse(hexCode.padRight(6, '0').substring(0, 6), radix: 16);
      return Color(colorInt + 0xFF000000).withOpacity(opacityPercentage / 100.0);
    } catch (e) {
      // Fallback color if hex is invalid
      return Colors.black.withOpacity(opacityPercentage / 100.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only draw the box if there is text to display
    if (text.isEmpty) return const SizedBox.shrink();

    final bgColor = _parseColor(prefs.bgColorHex, prefs.overlayOpacity);
    final textColor = _parseColor(prefs.textColorHex, 100);
    final double baseFontSize = 16.0;

    return IgnorePointer( // Prevents touch interactions on the subtitle
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey(text),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              color: textColor,
              fontSize: baseFontSize * prefs.fontSizeScale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}