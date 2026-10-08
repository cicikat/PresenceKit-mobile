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
  final retainedIds = <int>{};
  for (final source in [previous, local]) {
    final matches = _matches(remote, source);
    final live = identical(source, local);
    final lastMatch = matches.keys.fold<int>(-1, (a, b) => a > b ? a : b);
    for (var i = 0; i < source.length; i++) {
      final item = source[i];
      final found = matches[i];
      if (found == null) {
        // A row already parked in history is retained even when the server log
        // has not caught up with it — dropping it there is what swallowed
        // delivered replies. A live row that has not matched yet simply stays
        // in `sent`, still on screen and still reachable by retry.
        if (retainedIds.contains(item.id)) continue;
        if (_remoteAlreadyOwns(remote, source, i)) {
          if (live) sent.removeWhere((m) => m.id == item.id);
          continue;
        }
        if (!(live ? i < lastMatch : item.retainOnRefresh)) continue;
        retainedIds.add(item.id);
        int? next;
        int? preceding;
        for (var j = i + 1; j < source.length; j++) {
          if (matches.containsKey(j)) {
            next = matches[j];
            break;
          }
        }
        for (var j = i - 1; j >= 0; j--) {
          if (matches.containsKey(j)) {
            preceding = matches[j];
            break;
          }
        }
        final slot =
            next ?? (preceding == null ? remote.length : preceding + 1);
        insertions
            .putIfAbsent(slot, () => [])
            .add(item.settled().copyWith(retainOnRefresh: true));
        if (live) sent.removeWhere((m) => m.id == item.id);
        continue;
      }
      // Keep server dates, local key and the whole local rich payload.
      // A rich bubble (upload, sticker, reply quote, inline display) renders
      // from local state; the server log only carries its flattened text.
      final keepRich =
          item.attachments.isNotEmpty ||
          item.sticker != null ||
          item.quotedText != null ||
          (item.displayText?.isNotEmpty == true);
      result[found] = ChatMessage(
        id: item.id,
        role: item.role,
        text: keepRich ? item.text : remote[found].text,
        time: remote[found].time,
        dateKey: remote[found].dateKey,
        displayText: item.displayText ?? remote[found].displayText,
        toolActivity: remote[found].toolActivity,
        timestamp: remote[found].timestamp,
        turnId: remote[found].turnId ?? _turn(source, i),
        sticker: item.sticker,
        attachments: item.attachments,
        uploadNote: item.uploadNote,
        quotedText: item.quotedText,
        quotedLabel: item.quotedLabel,
        retryReplyTo: item.retryReplyTo,
        failed: item.failed,
        uncertainSince: item.uncertainSince,
        requestId: remote[found].requestId ?? item.requestId,
        mediaRefs: remote[found].mediaRefs.isNotEmpty
            ? remote[found].mediaRefs
            : item.mediaRefs,
        artifacts: remote[found].artifacts.isNotEmpty
            ? remote[found].artifacts
            : item.artifacts,
        retainOnRefresh: keepRich || item.retainOnRefresh,
      );
      if (identical(source, local)) {
        sent.removeWhere((m) => m.id == item.id);
      }
    }
  }
  return [
    for (var i = 0; i <= result.length; i++) ...[
      ...?insertions[i],
      if (i < result.length) result[i],
    ],
  ];
}

/// True when the server transcript demonstrably already carries this row, so
/// retaining the local copy would show it twice. Identity alone is not enough:
/// one turn spans several bubbles. The remote row must also read the same, or
/// be the flattened log line of this upload.
bool _remoteAlreadyOwns(
  List<ChatMessage> remote,
  List<ChatMessage> source,
  int index,
) {
  final item = source[index];
  final identity = item.turnId?.isNotEmpty == true
      ? item.turnId
      : (item.requestId?.isNotEmpty == true ? item.requestId : null);
  if (identity == null) return false;
  bool sameIdentity(ChatMessage row) =>
      row.role == item.role &&
      (row.turnId == identity || row.requestId == identity);
  // A historical memory line can flatten the visible paragraph boundaries.
  // Compare the whole canonical turn, never a substring or global fingerprint.
  if (item.role == 'him' &&
      item.turnId != null &&
      item.text.isNotEmpty &&
      item.artifacts.isEmpty) {
    final localRows = source
        .where(
          (row) =>
              row.role == 'him' &&
              row.turnId == item.turnId &&
              row.text.isNotEmpty,
        )
        .toList();
    final remoteRows = remote
        .where(
          (row) =>
              row.role == 'him' &&
              row.turnId == item.turnId &&
              row.text.isNotEmpty,
        )
        .toList();
    String content(List<ChatMessage> rows) =>
        rows.map((row) => row.text).join().replaceAll(RegExp(r'\s+'), '');
    if (remoteRows.length > localRows.length &&
        content(remoteRows) == content(localRows)) {
      return true;
    }
  }
  final occurrence = source
      .take(index + 1)
      .where((row) => sameIdentity(row) && row.text == item.text)
      .length;
  var represented = 0;
  for (final candidate in remote) {
    if (candidate.role != item.role) continue;
    if (candidate.turnId != identity && candidate.requestId != identity) {
      continue;
    }
    if (candidate.text == item.text) {
      represented++;
      if (represented >= occurrence) return true;
    }
    if (item.attachments.isNotEmpty && _imagePlaceholder(candidate)) {
      return true;
    }
  }
  return false;
}

Map<int, int> _matches(List<ChatMessage> remote, List<ChatMessage> source) {
  final matches = <int, int>{};
  final used = <int>{};
  var cursor = 0;
  for (var i = 0; i < source.length; i++) {
    final item = source[i];
    // An unconfirmed send must not inherit the turn of a neighbouring bubble
    // (it would claim a later message's reply); only its own turn_id,
    // request_id or exact text can reconcile it.
    final turn = (item.failed || item.uncertain)
        ? (item.turnId?.isNotEmpty == true ? item.turnId : null)
        : _turn(source, i);
    // A sticker carries no text the log could echo, so identity is the only
    // honest match; without one it falls through to the retain path.
    if (item.sticker != null || item.artifacts.isNotEmpty) {
      if (turn == null) continue;
      for (var j = 0; j < remote.length; j++) {
        if (used.contains(j) || remote[j].role != item.role) continue;
        if (remote[j].artifacts.isNotEmpty != item.artifacts.isNotEmpty) {
          continue;
        }
        if (_turn(remote, j) != turn) continue;
        matches[i] = j;
        used.add(j);
        cursor = j + 1;
        break;
      }
      continue;
    }
    final candidates = <int>[];
    for (var j = 0; j < remote.length; j++) {
      final candidate = remote[j];
      if (used.contains(j) || candidate.role != item.role) continue;
      final remoteTurn = _turn(remote, j);
      if (item.requestId != null &&
          candidate.requestId != null &&
          item.requestId != candidate.requestId) {
        continue;
      }
      if (item.role != 'tool' &&
          turn != null &&
          remoteTurn != null &&
          turn != remoteTurn) {
        continue;
      }
      if (item.role == 'tool') {
        if (item.toolActivity?.eventId == candidate.toolActivity?.eventId) {
          candidates.add(j);
        }
      } else if (item.role == 'reasoning') {
        if (item.text.isNotEmpty && item.text == candidate.text) {
          candidates.add(j);
        }
      } else if (item.requestId != null &&
          item.requestId == candidate.requestId &&
          (item.role == 'you' || item.text == candidate.text)) {
        candidates.add(j);
      } else if (turn != null && turn == remoteTurn) {
        // A turn contains multiple paragraphs: identity bounds the search,
        // but must not overwrite an unrelated paragraph with local styling.
        final unique =
            source
                    .where((m) => m.role == item.role && m.turnId == turn)
                    .length ==
                1 &&
            remote
                    .where((m) => m.role == item.role && m.turnId == turn)
                    .length ==
                1;
        if (item.text == candidate.text ||
            item.attachments.isNotEmpty ||
            unique) {
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
    if (candidates.isEmpty) continue;
    // A preview may replace only an unambiguous user slot. Ambiguity is first
    // resolved by canonical turn; if it survives, the local bubble is retained
    // as-is rather than collapsed onto a log row.
    if (item.attachments.isNotEmpty && candidates.length != 1) {
      if (turn == null) continue;
      final byTurn = candidates.where((j) => _turn(remote, j) == turn).toList();
      if (byTurn.length != 1) continue;
      candidates
        ..clear()
        ..add(byTurn.first);
    }
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
  if (item.role == 'tool' || item.role == 'narration') return null;
  if (item.role == 'reasoning') return item.text.isEmpty ? null : item.text;
  final direction = item.role == 'you' ? 1 : -1;
  for (
    var j = index + direction;
    j >= 0 && j < messages.length;
    j += direction
  ) {
    final neighbour = messages[j];
    if (neighbour.role == 'reasoning') {
      return neighbour.text.isEmpty ? null : neighbour.text;
    }
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
