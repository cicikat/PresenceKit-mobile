import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import 'reference_art.dart';

class LetterFlowText extends StatelessWidget {
  const LetterFlowText({super.key, required this.span, required this.c});
  final TextSpan span;
  final YxPalette c;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const artWidth = 96.0, artHeight = 105.0, overlap = 35.0, gap = 12.0;
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final narrow = math.max(1.0, box.maxWidth - artWidth - gap);
      final painter = TextPainter(
        text: span,
        textDirection: direction,
        textScaler: scaler,
      )..layout(maxWidth: narrow);
      final lines = painter.computeLineMetrics();
      var split = 0;
      for (final line in lines) {
        if (line.baseline + line.descent > artHeight - overlap && split > 0) {
          break;
        }
        final position = painter.getPositionForOffset(
          Offset(narrow, line.baseline),
        );
        split = painter.getLineBoundary(position).end;
        if (line.baseline + line.descent > artHeight - overlap) break;
      }
      final plain = span.toPlainText();
      split = split.clamp(0, plain.length);
      if (split < plain.length && plain[split] == '\n') split++;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text.rich(_slice(span, 0, split))),
              const SizedBox(width: gap),
              SizedBox(
                width: artWidth,
                height: artHeight - overlap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -overlap,
                      left: 0,
                      right: 0,
                      height: artHeight,
                      child: ExcludeSemantics(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(55),
                          ),
                          child: ReferenceLandscape(c: c, height: artHeight),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (split < plain.length)
            Text.rich(_slice(span, split, plain.length)),
        ],
      );
    },
  );

  TextSpan _slice(TextSpan source, int start, int end) {
    var offset = 0;
    final parts = <TextSpan>[];
    void visit(TextSpan node, TextStyle? inherited) {
      final style = inherited?.merge(node.style) ?? node.style;
      final text = node.text ?? '';
      final from = math.max(0, start - offset);
      final to = math.min(text.length, end - offset);
      if (from < to) {
        parts.add(TextSpan(text: text.substring(from, to), style: style));
      }
      offset += text.length;
      for (final child in node.children ?? const <InlineSpan>[]) {
        if (child is TextSpan) visit(child, style);
      }
    }

    visit(source, null);
    return TextSpan(style: source.style, children: parts);
  }
}
