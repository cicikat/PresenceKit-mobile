import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

/// Inert text markup shared by Android and web. No DOM mounting or network IO.
class InlineDisplayRun {
  const InlineDisplayRun(this.text, [this.tag, this.styles = const {}]);
  final String text;
  final String? tag;
  final Map<String, String> styles;
}

const _tags = {
  'hl',
  'big',
  'sm',
  'b',
  'strong',
  'i',
  'em',
  'u',
  's',
  'del',
  'small',
  'span',
  'font',
  'br',
  'p',
  'div',
  'blockquote',
  'pre',
  'code',
  'ul',
  'ol',
  'li',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'a',
};
const _blocks = {
  'p',
  'div',
  'blockquote',
  'pre',
  'ul',
  'ol',
  'li',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
};
const _properties = {
  'color',
  'background-color',
  'font-weight',
  'font-style',
  'font-size',
  'text-decoration',
  'font-family',
};

bool hasDisplayMarkup(String text) => RegExp(
  '<(?:${_tags.join('|')})(?:\\s|/?>)',
  caseSensitive: false,
).hasMatch(text);

List<InlineDisplayRun> parseInlineDisplay(String text) {
  if (!hasDisplayMarkup(text) &&
      !RegExp(
        r'&(?:#\d+|#x[\da-f]+|[a-z]+);',
        caseSensitive: false,
      ).hasMatch(text)) {
    return [InlineDisplayRun(text)];
  }
  for (final tag in ['hl', 'big', 'sm']) {
    if (RegExp('<$tag>').allMatches(text).length !=
        RegExp('</$tag>').allMatches(text).length) {
      return [InlineDisplayRun(text)];
    }
  }
  final runs = <InlineDisplayRun>[];
  void newline() {
    if (runs.isNotEmpty && !runs.last.text.endsWith('\n')) {
      runs.add(const InlineDisplayRun('\n'));
    }
  }

  void visit(
    dom.Node node,
    Map<String, String> inherited,
    String? tag,
    int depth,
  ) {
    if (node is dom.Text) {
      runs.add(InlineDisplayRun(node.data, tag, inherited));
      return;
    }
    if (node is! dom.Element) return;
    final name = node.localName ?? '';
    if (!_tags.contains(name) || depth > 64) {
      runs.add(InlineDisplayRun(node.outerHtml, tag, inherited));
      return;
    }
    if (name == 'br') {
      runs.add(const InlineDisplayRun('\n'));
      return;
    }
    if (_blocks.contains(name)) newline();
    final styles = Map<String, String>.of(inherited);
    if (name == 'b' ||
        name == 'strong' ||
        name.startsWith('h') && name != 'hl') {
      styles['font-weight'] = 'bold';
    }
    if (name == 'i' || name == 'em') styles['font-style'] = 'italic';
    if (name == 'u') styles['text-decoration'] = 'underline';
    if (name == 's' || name == 'del') {
      styles['text-decoration'] = 'line-through';
    }
    if (name == 'code' || name == 'pre') styles['font-family'] = 'monospace';
    if (name == 'small') styles['font-size'] = '0.85em';
    if (name == 'font' && node.attributes['color'] != null) {
      styles['color'] = node.attributes['color']!;
    }
    for (final declaration in (node.attributes['style'] ?? '').split(';')) {
      final colon = declaration.indexOf(':');
      if (colon < 0) continue;
      final key = declaration.substring(0, colon).trim().toLowerCase();
      final value = declaration.substring(colon + 1).trim();
      if (_properties.contains(key) &&
          value.length <= 100 &&
          !value.contains(RegExp(r'[<>"&]'))) {
        styles[key] = value;
      }
    }
    final displayTag = ['hl', 'big', 'sm'].contains(name) ? name : tag;
    if (name == 'li') runs.add(InlineDisplayRun('• ', displayTag, styles));
    for (final child in node.nodes) {
      visit(child, styles, displayTag, depth + 1);
    }
    if (_blocks.contains(name)) newline();
  }

  for (final node in parseFragment(text).nodes) {
    visit(node, const {}, null, 0);
  }
  if (runs.isNotEmpty && runs.last.text == '\n') runs.removeLast();
  return runs;
}

String inlinePlainText(String text) =>
    parseInlineDisplay(text).map((run) => run.text).join();

List<InlineDisplayRun> validatedInlineDisplay(
  String text,
  String? displayText,
) {
  final canonical = parseInlineDisplay(text);
  if (displayText == null) return canonical;
  final runs = parseInlineDisplay(displayText);
  return runs.map((run) => run.text).join() ==
          canonical.map((run) => run.text).join()
      ? runs
      : canonical;
}

/// Slice styling by visible text offsets, never by raw tag offsets.
List<String?> inlineDisplayParts(
  String text,
  String? displayText,
  List<String> parts,
) {
  if (displayText == null) return List.filled(parts.length, null);
  final runs = validatedInlineDisplay(text, displayText);
  final plain = inlinePlainText(text);
  var searchFrom = 0;
  return parts.map((part) {
    final start = plain.indexOf(inlinePlainText(part), searchFrom);
    if (start < 0) return null;
    final end = start + inlinePlainText(part).length;
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
        final escaped = fragment
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');
        final styled = run.styles.isEmpty
            ? escaped
            : '<span style="${run.styles.entries.map((e) => '${e.key}:${e.value}').join(';')}">$escaped</span>';
        result.write(
          run.tag == null ? styled : '<${run.tag}>$styled</${run.tag}>',
        );
      }
      offset = runEnd;
    }
    return result.toString();
  }).toList();
}
