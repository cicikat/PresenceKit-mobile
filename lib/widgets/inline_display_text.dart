import 'package:flutter/material.dart';

import '../models/inline_display.dart';

/// Parse before revealing so tag characters never flash during typing.
TextSpan inlineDisplaySpan({
  required String text,
  String? displayText,
  required TextStyle style,
  required Color accent,
  int? visibleCharacters,
  String cursor = '',
}) {
  var remaining = visibleCharacters ?? text.characters.length;
  final children = <InlineSpan>[];
  for (final run in validatedInlineDisplay(text, displayText)) {
    if (remaining <= 0) break;
    final visible = run.text.characters.take(remaining).toString();
    remaining -= visible.characters.length;
    final runStyle = switch (run.tag) {
      'hl' => style.copyWith(color: accent, fontWeight: FontWeight.w600),
      'big' => style.copyWith(fontSize: (style.fontSize ?? 16) * 1.18),
      'sm' => style.copyWith(
        fontSize: (style.fontSize ?? 16) * .85,
        color: (style.color ?? Colors.black).withValues(
          alpha: (style.color ?? Colors.black).a * .8,
        ),
      ),
      _ => style,
    };
    children.add(TextSpan(text: visible, style: runStyle));
  }
  if (cursor.isNotEmpty) children.add(TextSpan(text: cursor));
  return TextSpan(style: style, children: children);
}
