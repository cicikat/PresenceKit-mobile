import '../models/app_models.dart';

/// Merge ordered transcripts, retaining local identity and attachments.
/// Reasoning identity is canonical; clock labels are only a legacy fallback.
List<ChatMessage> reconcileChatHistory(
  List<ChatMessage> remote,
  List<ChatMessage> previous,
  List<ChatMessage> local,
  List<ChatMessage> sent,
) {
  final result = List<ChatMessage>.of(remote);
  final insertions = <int, List<ChatMessage>>{};
  for (final source in [previous, local]) {
    final matches = _matches(remote, source);
    final live = identical(source, local);
    final lastMatch = matches.keys.fold<int>(-1, (a, b) => a > b ? a : b);
    for (var i = 0; i < source.length; i++) {
      final item = source[i];
      final found = matches[i];
      if (found == null) {
        if (!(live ? i < lastMatch : item.retainOnRefresh)) continue;
        int? next;
        int? preceding;
        for (var j = i + 1; j < source.length; j++) {
          if (matches.containsKey(j)) { next = matches[j]; break; }
        }
        for (var j = i - 1; j >= 0; j--) {
          if (matches.containsKey(j)) { preceding = matches[j]; break; }
        }
        final slot = next ?? (preceding == null ? remote.length : preceding + 1);
        insertions.putIfAbsent(slot, () => []).add(item.settled().copyWith(retainOnRefresh: true));
        if (live) sent.removeWhere((m) => m.id == item.id);
        continue;
      }
      // Keep server dates and display projection, local key and rich payload.
      final keepImage = item.attachments.isNotEmpty;
      result[found] = ChatMessage(
        id: item.id,
        role: item.role,
        text: keepImage ? item.text : remote[found].text,
        time: remote[found].time,
        dateKey: remote[found].dateKey,
        displayText: keepImage
            ? item.displayText
            : remote[found].displayText ?? item.displayText,
        toolActivity: remote[found].toolActivity,
        timestamp: remote[found].timestamp,
        turnId: remote[found].turnId ?? _turn(source, i),
        sticker: item.sticker,
        attachments: item.attachments,
        uploadNote: item.uploadNote,
        quotedText: item.quotedText,
        quotedLabel: item.quotedLabel,
        retainOnRefresh: keepImage || item.retainOnRefresh,
      );
      if (identical(source, local)) {
        sent.removeWhere((m) => m.id == item.id);
      }
    }
  }
  return [for (var i = 0; i <= result.length; i++) ...[
    ...?insertions[i],
    if (i < result.length) result[i],
  ]];
}

Map<int, int> _matches(List<ChatMessage> remote, List<ChatMessage> source) {
  final matches = <int, int>{};
  final used = <int>{};
  var cursor = 0;
  for (var i = 0; i < source.length; i++) {
    final item = source[i];
    if (item.failed || item.sticker != null) continue;
    final turn = _turn(source, i);
    final candidates = <int>[];
    for (var j = 0; j < remote.length; j++) {
      final candidate = remote[j];
      if (used.contains(j) || candidate.role != item.role) continue;
      final remoteTurn = _turn(remote, j);
      if (turn != null && remoteTurn != null && turn != remoteTurn) continue;
      if (item.role == 'tool') {
        if (item.toolActivity?.eventId == candidate.toolActivity?.eventId) { candidates.add(j); }
      } else if (item.role == 'reasoning') {
        if (item.text.isNotEmpty && item.text == candidate.text) { candidates.add(j); }
      } else if (turn != null && turn == remoteTurn) {
        if (item.text == candidate.text ||
            (item.role == 'you' && item.attachments.isNotEmpty) ||
            (item.role == 'you' && _imagePlaceholder(candidate))) {
          candidates.add(j);
        }
      } else if (j >= cursor &&
          (item.text == candidate.text ||
              (item.role == 'you' &&
                  item.attachments.isNotEmpty &&
                  _imagePlaceholder(candidate))) &&
          _sameClock(candidate, item)) {
        candidates.add(j);
      }
    }
    // A preview may replace only an unambiguous user slot in its canonical turn.
    if (item.attachments.isNotEmpty && candidates.length != 1) continue;
    if (candidates.isEmpty) continue;
    final found = candidates.first;
    matches[i] = found;
    used.add(found);
    cursor = found + 1;
  }
  return matches;
}

String? _turn(List<ChatMessage> messages, int index) {
  final item = messages[index];
  if (item.turnId?.isNotEmpty == true) return item.turnId;
  if (item.role == 'reasoning') return item.text.isEmpty ? null : item.text;
  final direction = item.role == 'you' ? 1 : -1;
  for (var j = index + direction; j >= 0 && j < messages.length; j += direction) {
    final neighbour = messages[j];
    if (neighbour.role == 'reasoning') return neighbour.text.isEmpty ? null : neighbour.text;
    if (neighbour.role != item.role) break;
  }
  return null;
}

bool _imagePlaceholder(ChatMessage message) =>
    AttachmentPlaceholder.parse(message.text)?.isImage == true;

bool _sameClock(ChatMessage remote, ChatMessage local) {
  final date =
      local.dateKey ??
      '${local.timestamp.year}-${local.timestamp.month.toString().padLeft(2, '0')}-${local.timestamp.day.toString().padLeft(2, '0')}';
  if (remote.dateKey != date) return false;
  // Local labels can contain seconds; legacy logs only contain HH:mm.
  final clock = RegExp(r'^\d{2}:\d{2}');
  return clock.firstMatch(remote.time)?.group(0) != null &&
      clock.firstMatch(remote.time)?.group(0) ==
          clock.firstMatch(local.time)?.group(0);
}
