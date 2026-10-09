/// Recover display-only quotes from known, anchored server reply envelopes.
({String text, String? quote}) historyUserDisplay(String raw) {
  final current = RegExp(
    r'^用户引用回复：(作者=(?:用户|角色)，时间=[^，\n]+，message_id=[^，\n]+|旧引用无稳定锚点，作者未经核验，客户端时间=[^，\n]+)，原文「([\s\S]*?)」：',
  ).firstMatch(raw);
  if (current != null) {
    return (text: raw.substring(current.end), quote: current.group(2));
  }
  final legacy = RegExp(
    r'^用户回复了你(?:今天 \d{2}:\d{2}|\d+天前|\d+月\d+日)发送的这条消息「([\s\S]*?)」：',
  ).firstMatch(raw);
  if (legacy != null) {
    return (text: raw.substring(legacy.end), quote: legacy.group(1));
  }
  return (text: raw, quote: null);
}
