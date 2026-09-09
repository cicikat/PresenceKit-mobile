import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Placed outside Scaffold's keyboard-resized body. Dialogs and IME only
/// relayout the foreground; the wallpaper retains the window's geometry.
class SceneBackground extends StatelessWidget {
  const SceneBackground({
    super.key,
    required this.bytes,
    required this.color,
    required this.child,
    this.blur = 0,
    this.darken = false,
  });
  final Uint8List? bytes;
  final Color color;
  final Widget child;
  final double blur;
  final bool darken;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ColoredBox(color: color),
      if (bytes != null)
        Positioned.fill(
          child: ClipRect(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Image.memory(
                bytes!,
                key: const ValueKey('scene-wallpaper'),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                gaplessPlayback: true,
                color: darken ? Colors.black.withValues(alpha: .28) : null,
                colorBlendMode: darken ? BlendMode.darken : null,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      child,
    ],
  );
}
