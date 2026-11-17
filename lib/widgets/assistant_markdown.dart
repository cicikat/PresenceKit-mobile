import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'inline_display_text.dart';
import '../models/inline_display.dart';
import '../models/markdown_display.dart';

Uri? safeMarkdownUri(String value) {
  if (RegExp(r'[\s\x00-\x1f]').hasMatch(value)) return null;
  final uri = Uri.tryParse(value);
  return uri != null &&
          {'http', 'https'}.contains(uri.scheme.toLowerCase()) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown({
    super.key,
    required this.text,
    required this.style,
    required this.accent,
    this.openLink,
  });
  final String text;
  final TextStyle style;
  final Color accent;
  final Future<void> Function(Uri)? openLink;
  @override
  Widget build(BuildContext context) {
    // Preserve the existing inert HTML typography for legacy messages; mixed
    // Markdown uses only the three explicitly supported display tags below.
    if (hasDisplayMarkup(text) && !hasMarkdownSyntax(text)) {
      return Text.rich(
        inlineDisplaySpan(text: text, style: style, accent: accent),
      );
    }
    final theme = Theme.of(context);
    final heading = style.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: (style.fontSize ?? 16) * 1.12,
    );
    return MarkdownBody(
      data: text,
      fitContent: true,
      softLineBreak: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [_LegacyInline(), _LiteralHtmlInline()],
      blockSyntaxes: [_LegacyBlock(), _LiteralHtmlBlock()],
      builders: {
        for (final tag in ['hl', 'big', 'sm'])
          tag: _LegacyBuilder(style, accent),
      },
      // The existing bubble menu continues to own copy and text selection.
      selectable: false,
      imageBuilder: (uri, title, alt) => Text(alt ?? '', style: style),
      onTapLink: (label, href, title) async {
        final uri = safeMarkdownUri(href ?? '');
        if (uri == null) return;
        if (openLink != null) {
          await openLink!(uri);
        } else {
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {}
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: style,
        h1: heading,
        h2: heading,
        h3: heading,
        h4: heading,
        h5: heading,
        h6: heading,
        strong: style.copyWith(fontWeight: FontWeight.bold),
        em: style.copyWith(fontStyle: FontStyle.italic),
        del: style.copyWith(decoration: TextDecoration.lineThrough),
        code: style.copyWith(
          fontFamily: 'monospace',
          fontSize: (style.fontSize ?? 16) * .9,
        ),
        blockquote: style,
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: .35,
          ),
          border: Border(
            left: BorderSide(color: accent.withValues(alpha: .6), width: 2),
          ),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        listBullet: style,
        tableBody: style,
        tableHead: style.copyWith(fontWeight: FontWeight.w600),
        a: style.copyWith(color: accent, decoration: TextDecoration.underline),
        tableColumnWidth: const IntrinsicColumnWidth(),
        blockSpacing: 8,
      ),
    );
  }
}

class _LegacyInline extends md.InlineSyntax {
  _LegacyInline() : super(r'<(hl|big|sm)>([^<]{0,200})</\1>');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element(match[1]!, parser.document.parseInline(match[2]!)),
    );
    return true;
  }
}

class _LegacyBlock extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^ {0,3}<(hl|big|sm)>');
  @override
  md.Node parse(md.BlockParser parser) {
    final lines = <String>[];
    do {
      lines.add(parser.current.content);
      parser.advance();
    } while (!parser.isDone &&
        parser.current.content.isNotEmpty &&
        !lines.last.contains(RegExp(r'</(?:hl|big|sm)>')));
    return md.Element('p', parser.document.parseInline(lines.join('\n')));
  }
}

class _LiteralHtmlInline extends md.InlineSyntax {
  _LiteralHtmlInline() : super(r'</?[A-Za-z][A-Za-z0-9-]*(?:\s[^>\n]*)?/?>');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Text(match[0]!));
    return true;
  }
}

class _LiteralHtmlBlock extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^ {0,3}</?[A-Za-z][A-Za-z0-9-]*(?:\s|/?>)');
  @override
  md.Node parse(md.BlockParser parser) {
    final lines = <String>[];
    do {
      lines.add(parser.current.content);
      parser.advance();
    } while (!parser.isDone && parser.current.content.isNotEmpty);
    return md.Element('p', [md.Text(lines.join('\n'))]);
  }
}

class _LegacyBuilder extends MarkdownElementBuilder {
  _LegacyBuilder(this.base, this.accent);
  final TextStyle base;
  final Color accent;
  TextSpan span(md.Node node, TextStyle style) {
    if (node is md.Text) return TextSpan(text: node.text, style: style);
    if (node is! md.Element) return const TextSpan();
    final next = switch (node.tag) {
      'hl' => style.copyWith(color: accent, fontWeight: FontWeight.w600),
      'big' => style.copyWith(fontSize: (style.fontSize ?? 16) * 1.18),
      'sm' => style.copyWith(fontSize: (style.fontSize ?? 16) * .85),
      'strong' => style.copyWith(fontWeight: FontWeight.bold),
      'em' => style.copyWith(fontStyle: FontStyle.italic),
      'del' => style.copyWith(decoration: TextDecoration.lineThrough),
      'code' => style.copyWith(fontFamily: 'monospace'),
      _ => style,
    };
    return TextSpan(
      style: next,
      children: [
        for (final child in node.children ?? <md.Node>[]) span(child, next),
      ],
    );
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Text.rich(span(element, base.merge(parentStyle)));
}
