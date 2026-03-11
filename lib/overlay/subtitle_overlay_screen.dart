// subtitle_overlay_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class SubtitleOverlay extends StatefulWidget {

  const SubtitleOverlay({super.key});

  @override
  State<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends State<SubtitleOverlay> {

  String text = "Waiting for speech...";
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = FlutterOverlayWindow.overlayListener.listen((data) {
      if (data != null && mounted) {
        setState(() {
          text = data.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel(); // Clean up the listener
    super.dispose();
  }

  void closeOverlay() {
    FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
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

              /// Subtitle text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: Text(
                  text,
                  key: ValueKey(text),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 6),

              /// Close button
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: closeOverlay,
                  child: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}