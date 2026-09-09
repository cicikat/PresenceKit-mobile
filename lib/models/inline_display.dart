/// Desktop-compatible inline markup. Never interprets arbitrary HTML.
class InlineDisplayRun {
  const InlineDisplayRun(this.text, [this.tag]);
  final String text;
  final String? tag;
}

final _inlineTag = RegExp(r'<(hl|big|sm)>([^<]{0,200})</\1>');

List<InlineDisplayRun> parseInlineDisplay(String text) {
  final runs = <InlineDisplayRun>[];
  var end = 0;
  for (final match in _inlineTag.allMatches(text)) {
    if (match.start > end) {
      runs.add(InlineDisplayRun(text.substring(end, match.start)));
    }
    runs.add(InlineDisplayRun(match.group(2)!, match.group(1)));
    end = match.end;
  }
  if (end < text.length) runs.add(InlineDisplayRun(text.substring(end)));
  return runs;
}

String inlinePlainText(String text) =>
    parseInlineDisplay(text).map((run) => run.text).join();

/// Styles are optional: a stale/malformed display copy cannot replace content.
List<InlineDisplayRun> validatedInlineDisplay(
  String text,
  String? displayText,
) {
  if (displayText == null) return [InlineDisplayRun(text)];
  final runs = parseInlineDisplay(displayText);
  return runs.map((run) => run.text).join() == text
      ? runs
      : [InlineDisplayRun(text)];
}

/// Slice styling by plain-text offsets, including tags spanning paragraphs.
/// [parts] come from the existing canonical paragraph splitter.
List<String?> inlineDisplayParts(
  String text,
  String? displayText,
  List<String> parts,
) {
  if (displayText == null) return List.filled(parts.length, null);
  final runs = validatedInlineDisplay(text, displayText);
  var searchFrom = 0;
  return parts.map((part) {
    final start = text.indexOf(part, searchFrom);
    if (start < 0) return null;
    final end = start + part.length;
    searchFrom = end;
    var offset = 0;
    final result = StringBuffer();
    for (final run in runs) {
      final runEnd = offset + run.text.length;
      if (offset < end && runEnd > start) {
        final fragment = run.text.substring(
          (start - offset).clamp(0, run.text.length),
          (end - offset).clamp(0, run.text.length),
        );
        result.write(
          run.tag == null ? fragment : '<${run.tag}>$fragment</${run.tag}>',
        );
      }
      offset = runEnd;
    }
    return result.toString();
  }).toList();
}
