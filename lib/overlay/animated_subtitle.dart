// animated_subtitle.dart
import 'package:flutter/material.dart';

class AnimatedSubtitle extends StatelessWidget {

  final String text;

  const AnimatedSubtitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {

    return AnimatedSwitcher(

      duration: const Duration(milliseconds: 250),

      transitionBuilder: (child, animation) {

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );

      },

      child: Text(
        text,
        key: ValueKey(text),

        textAlign: TextAlign.center,

        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
        ),
      ),
    );
  }
}