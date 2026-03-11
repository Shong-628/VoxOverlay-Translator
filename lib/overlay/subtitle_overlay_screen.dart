import 'package:flutter/material.dart';

class SubtitleOverlay extends StatelessWidget {

  final String text;
  final VoidCallback onClose;

  const SubtitleOverlay({
    super.key,
    required this.text,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 320,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          /// Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6),

          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onClose,
              child: const Icon(
                Icons.close,
                color: Colors.white70,
                size: 18,
              ),
            ),
          )
        ],
      ),
    );
  }
}