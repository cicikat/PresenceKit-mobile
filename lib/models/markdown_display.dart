/// Display grouping only: canonical message content is never rewritten.
bool hasMarkdownBlock(String text) =>
    RegExp(
      r'^(?: {0,3}(?:#{1,6}\s|>\s?|[-+*]\s|\d+[.)]\s|`{3,}|~{3,})| {4}\S)',
      multiLine: true,
    ).hasMatch(text) ||
    RegExp(
      r'^\s*\|?.+\|.*\r?\n\s*\|?\s*:?-{3,}',
      multiLine: true,
    ).hasMatch(text);

bool hasMarkdownSyntax(String text) =>
    hasMarkdownBlock(text) ||
    RegExp(
      r'(`[^`]+`|\*\*[^*]+\*\*|\*[^*\n]+\*|_[^_\n]+_|~~[^~]+~~|!?\[[^\]]*\]\([^\n]+\))',
    ).hasMatch(text);
