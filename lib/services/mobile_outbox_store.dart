import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/app_models.dart';
import '../models/screen_context.dart';

enum OutboxState { queued, sending, outcomeUnknown, retryableFailed, blocked }

class OutboxEntry {
  OutboxEntry({
    required this.requestId,
    required this.scope,
    required this.sequence,
    required this.createdAt,
    required this.text,
    this.replyTo,
    this.files = const [],
    this.caption = '',
    this.voiceReceipt,
    this.state = OutboxState.queued,
  });

  final String requestId;
  final String scope;
  final int sequence;
  final DateTime createdAt;
  final String text;
  final ReplyTarget? replyTo;
  final List<PickedUploadFile> files;
  final String caption;
  final String? voiceReceipt;
  final OutboxState state;

  OutboxEntry withState(OutboxState value) => OutboxEntry(
    requestId: requestId,
    scope: scope,
    sequence: sequence,
    createdAt: createdAt,
    text: text,
    replyTo: replyTo,
    files: files,
    caption: caption,
    voiceReceipt: voiceReceipt,
    state: value,
  );

  Map<String, Object?> _wirePayload() => {
    'text': text,
    'reply_to': replyTo?.toJson(),
    'files': [
      for (final file in files)
        {'name': file.name, 'bytes': base64Encode(file.bytes)},
    ],
    'caption': caption,
    'voice_receipt': voiceReceipt,
  };

  Map<String, Object?> toJson() {
    final payload = _wirePayload();
    return {
      'request_id': requestId,
      'scope': scope,
      'local_seq': sequence,
      'created_at': createdAt.toUtc().toIso8601String(),
      'payload_digest': _digest(payload),
      ...payload,
      'state': state.name,
    };
  }

  static String _digest(Map<String, Object?> payload) =>
      sha256.convert(utf8.encode(jsonEncode(payload))).toString();

  factory OutboxEntry.fromJson(Map<String, dynamic> json) {
    final quote = json['reply_to'] as Map<String, dynamic>?;
    final state = OutboxState.values.byName(json['state'] as String);
    final row = OutboxEntry(
      requestId: json['request_id'] as String,
      scope: json['scope'] as String,
      sequence: json['local_seq'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      text: json['text'] as String,
      replyTo: quote == null
          ? null
          : ReplyTarget(
              text: quote['text'] as String,
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                ((quote['ts'] as num) * 1000).round(),
              ),
              messageId: quote['message_id'] as String?,
            ),
      files: [
        for (final file in json['files'] as List<dynamic>)
          PickedUploadFile(
            name: file['name'] as String,
            bytes: base64Decode(file['bytes'] as String),
          ),
      ],
      caption: json['caption'] as String,
      voiceReceipt: json['voice_receipt'] as String?,
      state: state == OutboxState.sending ? OutboxState.outcomeUnknown : state,
    );
    if (_digest(row._wirePayload()) != json['payload_digest']) {
      throw const FormatException('outbox_payload_digest');
    }
    return row;
  }
}

/// The write callback must complete only after an atomic durable commit.
/// All reads and transactions are serialized, including across UI generations.
class MobileOutboxStore {
  MobileOutboxStore(this._read, this._write);
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;

  static const maxEntries = 100;
  static const maxSnapshotBytes = 64 * 1024 * 1024;

  Future<void> _tail = Future.value();
  List<OutboxEntry>? _entries;
  int _sequence = 0;
  int corruptEntries = 0;

  Future<T> _run<T>(Future<T> Function(List<OutboxEntry>) action) {
    final result = _tail.then((_) async {
      if (_entries == null) {
        final raw = await _read();
        final rows = <OutboxEntry>[];
        var corrupt = 0;
        if (raw != null) {
          final snapshot = jsonDecode(raw) as Map<String, dynamic>;
          if (snapshot['version'] != 1) {
            throw const FormatException('outbox_version');
          }
          _sequence = snapshot['sequence'] as int;
          final seen = <String>{};
          for (final item in snapshot['entries'] as List<dynamic>) {
            try {
              final row = OutboxEntry.fromJson(item as Map<String, dynamic>);
              if (row.sequence <= 0 ||
                  row.sequence > _sequence ||
                  row.requestId.isEmpty ||
                  row.scope.isEmpty ||
                  !seen.add(row.requestId)) {
                throw const FormatException('outbox_entry');
              }
              rows.add(row);
            } on Exception {
              corrupt++;
            } on TypeError {
              corrupt++;
            }
          }
          rows.sort((a, b) => a.sequence.compareTo(b.sequence));
          corrupt += (snapshot['corrupt_entries'] as int?) ?? 0;
        }
        corruptEntries = corrupt;
        _entries = rows;
      }
      return action(_entries!);
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _commit(List<OutboxEntry> rows, int sequence) async {
    final snapshot = jsonEncode({
      'version': 1,
      'sequence': sequence,
      'corrupt_entries': corruptEntries,
      'entries': rows.map((row) => row.toJson()).toList(),
    });
    if (utf8.encode(snapshot).length > maxSnapshotBytes) {
      throw StateError('outbox_capacity');
    }
    await _write(snapshot);
    _sequence = sequence;
    _entries = rows;
  }

  Future<OutboxEntry> enqueue(OutboxEntry Function(int) create) =>
      _run((rows) async {
        if (rows.length >= maxEntries) throw StateError('outbox_capacity');
        final row = create(_sequence + 1);
        await _commit([...rows, row], row.sequence);
        return row;
      });

  Future<List<OutboxEntry>> readScope(String scope) =>
      _run((rows) async => rows.where((row) => row.scope == scope).toList());

  Future<bool> setState(
    OutboxEntry row,
    OutboxState? state, {
    bool requireCurrent = false,
  }) => _run((rows) async {
    final index = rows.indexWhere(
      (candidate) =>
          candidate.scope == row.scope && candidate.requestId == row.requestId,
    );
    if (index < 0) return false;
    if ((requireCurrent || state != null) && rows[index].state != row.state) {
      return false;
    }
    final next = [...rows];
    if (state == null) {
      next.removeAt(index);
    } else {
      next[index] = row.withState(state);
    }
    await _commit(next, _sequence);
    return true;
  });
}
