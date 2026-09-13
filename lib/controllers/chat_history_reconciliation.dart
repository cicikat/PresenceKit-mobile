import '../models/app_models.dart';

/// Keep the server's transcript order, while retaining local identity/attachments.
/// Reasoning identity is canonical; clock labels are only a legacy fallback.
List<ChatMessage> reconcileChatHistory(
  List<ChatMessage> remote,
  List<ChatMessage> previous,
  List<ChatMessage> local,
  List<ChatMessage> sent,
) {
  final result = List<ChatMessage>.of(remote);
  final used = <int>{};
  for (final source in [previous, local]) {
    var cursor = 0;
    for (var i = 0; i < source.length; i++) {
      final item = source[i];
      if (item.failed) continue;
      var start = cursor;
      var end = remote.length;
      // A local send is bounded by its canonical reasoning anchor. This lets
      // replies completed minutes later reconcile without guessing a turn ID.
      final anchorIndex = item.role == 'you'
          ? i + 1
          : source.lastIndexWhere((m) => m.role == 'reasoning', i);
      var anchored = false;
      if (anchorIndex >= 0 && anchorIndex < source.length) {
        final anchor = source[anchorIndex];
        final at = remote.indexWhere(
          (m) =>
              m.role == 'reasoning' &&
              anchor.role == 'reasoning' &&
              anchor.text.isNotEmpty &&
              m.text == anchor.text,
        );
        if (at >= 0) {
          anchored = true;
          if (item.role == 'you') {
            start = at;
            while (start > 0 && remote[start - 1].role == 'you') {
              start--;
            }
            end = at;
          } else if (item.role == 'him') {
            start = at + 1;
            end = start;
            while (end < remote.length && remote[end].role == 'him') {
              end++;
            }
          }
        }
      }
      var found = -1;
      for (var j = start; j < end; j++) {
        final candidate = remote[j];
        if (used.contains(j) ||
            candidate.role != item.role ||
            candidate.text != item.text) {
          continue;
        }
        if (item.role == 'reasoning'
            ? item.text.isNotEmpty
            : anchored || _sameClock(candidate, item)) {
          found = j;
          break;
        }
      }
      if (found < 0) continue;
      used.add(found);
      cursor = found + 1;
      // Keep server dates and display projection, local key and rich payload.
      result[found] = ChatMessage(
        id: item.id,
        role: item.role,
        text: item.text,
        time: remote[found].time,
        dateKey: remote[found].dateKey,
        displayText: remote[found].displayText ?? item.displayText,
        toolActivity: remote[found].toolActivity,
        timestamp: item.timestamp,
        sticker: item.sticker,
        attachments: item.attachments,
        uploadNote: item.uploadNote,
        quotedText: item.quotedText,
        quotedLabel: item.quotedLabel,
      );
      if (identical(source, local)) {
        sent.removeWhere((m) => m.id == item.id);
      }
    }
    // Prior history only lends stable widget keys; local delivery can also match.
    if (identical(source, previous)) used.clear();
  }
  return result;
}

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
