import 'package:flutter/material.dart';
import 'animated_subtitle.dart';

class FloatingBubble extends StatefulWidget {

  final String text;

  const FloatingBubble({super.key, required this.text});

  @override
  State<FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<FloatingBubble> {

  bool expanded = false;

  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: () {
        setState(() {
          expanded = !expanded;
        });
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),

        width: expanded ? 320 : 60,
        height: expanded ? 120 : 60,

        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(30),
        ),

        child: expanded
            ? Center(
          child: AnimatedSubtitle(text: widget.text),
        )
            : const Icon(
          Icons.translate,
          color: Colors.white,
        ),
      ),
    );
  }
}