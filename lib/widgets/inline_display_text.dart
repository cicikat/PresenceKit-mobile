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
  final runs = validatedInlineDisplay(text, displayText);
  var remaining =
      visibleCharacters ?? runs.map((run) => run.text).join().characters.length;
  final children = <InlineSpan>[];
  for (final run in runs) {
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
    children.add(
      TextSpan(text: visible, style: _htmlStyle(runStyle, run.styles)),
    );
  }
  if (cursor.isNotEmpty) children.add(TextSpan(text: cursor));
  return TextSpan(style: style, children: children);
}

Color? _htmlColor(String? value) {
  if (value == null) return null;
  final named = <String, Color>{
    'red': Colors.red,
    'green': const Color(0xff008000),
    'blue': Colors.blue,
    'black': Colors.black,
    'white': Colors.white,
    'gray': Colors.grey,
    'grey': Colors.grey,
    'yellow': Colors.yellow,
    'purple': Colors.purple,
    'orange': Colors.orange,
    'transparent': Colors.transparent,
  };
  final text = value.trim().toLowerCase();
  if (named.containsKey(text)) return named[text];
  if (RegExp(r'^#[0-9a-f]{3}$').hasMatch(text)) {
    final hex = text.substring(1).split('').map((c) => '$c$c').join();
    return Color(int.parse('ff$hex', radix: 16));
  }
  if (RegExp(r'^#[0-9a-f]{6}$').hasMatch(text)) {
    return Color(int.parse('ff${text.substring(1)}', radix: 16));
  }
  final rgb = RegExp(
    r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)$',
  ).firstMatch(text);
  if (rgb != null) {
    return Color.fromRGBO(
      int.parse(rgb[1]!).clamp(0, 255),
      int.parse(rgb[2]!).clamp(0, 255),
      int.parse(rgb[3]!).clamp(0, 255),
      (double.tryParse(rgb[4] ?? '1') ?? 1).clamp(0, 1),
    );
  }
  return null;
}

TextStyle _htmlStyle(TextStyle base, Map<String, String> css) {
  var size = base.fontSize ?? 16;
  final rawSize = css['font-size'];
  if (rawSize != null) {
    final number = double.tryParse(
      rawSize.replaceAll(RegExp(r'(px|em|%)$'), ''),
    );
    if (number != null && number.isFinite && number > 0) {
      size = rawSize.endsWith('em')
          ? size * number
          : rawSize.endsWith('%')
          ? size * number / 100
          : number;
    }
  }
  final weight = css['font-weight'];
  return base.copyWith(
    color: _htmlColor(css['color']),
    backgroundColor: _htmlColor(css['background-color']),
    fontSize: size.clamp(6, 96),
    fontWeight:
        weight == 'bold' ||
            weight == 'bolder' ||
            (int.tryParse(weight ?? '') ?? 0) >= 600
        ? FontWeight.bold
        : weight == 'normal'
        ? FontWeight.normal
        : null,
    fontStyle: css['font-style'] == 'italic'
        ? FontStyle.italic
        : css['font-style'] == 'normal'
        ? FontStyle.normal
        : null,
    fontFamily: css['font-family'] == 'monospace' ? 'monospace' : null,
    decoration: css['text-decoration']?.contains('underline') == true
        ? TextDecoration.underline
        : css['text-decoration']?.contains('line-through') == true
        ? TextDecoration.lineThrough
        : null,
  );
}
