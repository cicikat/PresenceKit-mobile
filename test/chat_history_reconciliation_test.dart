import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_history_reconciliation.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/screen_context.dart';

ChatMessage message(
  String role,
  String text,
  String time, {
  bool failed = false,
}) => ChatMessage(
  role: role,
  text: text,
  time: time,
  dateKey: '2026-09-13',
  failed: failed,
);

void main() {
  test('a partial log cannot swallow the second identical paragraph of a turn', () {
    final prior = [
      for (var i = 0; i < 2; i++) ChatMessage(
        role: 'him', text: 'again', time: '12:00', turnId: 't', retainOnRefresh: true,
      ),
    ];
    final remote = [ChatMessage(role: 'him', text: 'again', time: '12:00', turnId: 't')];
    final result = reconcileChatHistory(remote, prior, [], []);
    expect(result.map((m) => m.text), ['again', 'again']);
    final refreshed = reconcileChatHistory(remote, result, [], []);
    expect(refreshed.map((m) => m.id), result.map((m) => m.id));
  });
  test(
    'partial same-turn history cannot duplicate or overwrite styled paragraphs',
    () {
      final first = ChatMessage(
        role: 'him',
        text: 'first',
        displayText: '<hl>first</hl>',
        time: '12:00',
        turnId: 't',
      );
      final second = ChatMessage(
        role: 'him',
        text: 'second',
        displayText: '<big>second</big>',
        time: '12:00',
        turnId: 't',
      );
      final remote = [
        ChatMessage(role: 'him', text: 'second', time: '12:00', turnId: 't'),
      ];
      final sent = [first, second];
      final merged = reconcileChatHistory(remote, [], List.of(sent), sent);
      expect(merged.map((m) => m.text), ['first', 'second']);
      expect(merged.map((m) => m.displayText), [
        '<hl>first</hl>',
        '<big>second</big>',
      ]);
      expect(sent, isEmpty);
      final refreshed = reconcileChatHistory(remote, merged, [], sent);
      expect(refreshed.map((m) => m.text), ['first', 'second']);
    },
  );
  test(
    'canonical turns reconcile clock drift and anchors without reordering repeated text',
    () {
      final remote = [
        message('you', 'yes', '12:03'),
        message('reasoning', 't1', ''),
        message('him', 'reply one', '12:03'),
        message('you', 'yes', '12:07'),
        message('reasoning', 't2', ''),
        message('him', 'reply two', '12:07'),
      ];
      final local = [
        message('you', 'yes', '12:00:12'),
        message('reasoning', 't1', '12:00'),
        message('him', 'reply one', '12:04'),
        message('you', 'yes', '12:05:20'),
        message('reasoning', 't2', '12:05'),
        message('him', 'reply two', '12:08'),
      ];
      final sent = [...local];
      final result = reconcileChatHistory(remote, [], local, sent);
      expect(sent, isEmpty);
      expect(result.map((m) => m.id), local.map((m) => m.id));
      expect(result.map((m) => m.text), [
        'yes',
        't1',
        'reply one',
        'yes',
        't2',
        'reply two',
      ]);
      final refreshed = reconcileChatHistory(remote, result, [], sent);
      expect(refreshed.map((m) => m.id), result.map((m) => m.id));
    },
  );

  test('legacy seconds normalize and occurrences stay distinct', () {
    final local = [
      message('you', 'yes', '12:00:10'),
      message('you', 'yes', '12:00:20'),
    ];
    final sent = [...local];
    final result = reconcileChatHistory(
      [message('you', 'yes', '12:00'), message('you', 'yes', '12:00')],
      [],
      local,
      sent,
    );
    expect(sent, isEmpty);
    expect(result.map((m) => m.id), local.map((m) => m.id));
  });

  test(
    'failed and pending messages remain available to the live retry path',
    () {
      final failed = message('you', 'failed', '12:00', failed: true);
      final local = [
        failed,
        message('you', 'sent', '12:01'),
        message('reasoning', 't1', '12:01'),
        message('him', 'reply', '12:02'),
      ];
      final pending = message('you', 'pending', '12:03');
      final sent = [...local, pending];
      final result = reconcileChatHistory(
        [
          message('you', 'sent', '12:01'),
          message('reasoning', 't1', ''),
          message('him', 'reply', '12:01'),
        ],
        [],
        local,
        sent,
      );
      expect(result.map((m) => m.text), ['failed', 'sent', 't1', 'reply']);
      expect(result.first.failed, isTrue);
      expect(result.first.id, failed.id);
      expect(sent.map((m) => m.id), [pending.id]);
    },
  );

  test('image bubbles keep local attachments instead of recognition text', () {
    final localImage = ChatMessage(
      role: 'you',
      text: 'photo.jpg',
      displayText: 'photo.jpg',
      time: '12:00:10',
      dateKey: '2026-09-13',
      turnId: 'turn-img',
      attachments: [
        PickedUploadFile(name: 'photo.jpg', bytes: Uint8List.fromList([1, 2, 3]),
        ),
      ],
    );
    final sent = [localImage];
    final result = reconcileChatHistory(
      [
        ChatMessage(
          role: 'you',
          text: '📎 photo.jpg\nA bowl of rice',
          time: '12:00',
          dateKey: '2026-09-13',
          turnId: 'turn-img',
        ),
        message('reasoning', 't1', ''),
        message('him', 'looks tasty', '12:01'),
      ],
      [],
      [localImage],
      sent,
    );
    expect(sent, isEmpty);
    expect(result.first.id, localImage.id);
    expect(result.first.attachments, isNotEmpty);
    expect(result.first.text, 'photo.jpg');
    expect(result.first.displayText, 'photo.jpg');
  });

  test('ocr text in the same turn still keeps the local image bubble', () {
    final localImage = ChatMessage(
      role: 'you',
      text: 'photo.jpg',
      time: '12:00:10',
      dateKey: '2026-09-13',
      turnId: 'turn-img',
      attachments: [
        PickedUploadFile(name: 'photo.jpg', bytes: Uint8List.fromList([1, 2, 3]),
        ),
      ],
    );
    final sent = [localImage];
    final result = reconcileChatHistory(
      [
        ChatMessage(
          role: 'you',
          text: 'A bowl of rice on the table',
          time: '12:00',
          dateKey: '2026-09-13',
          turnId: 'turn-img',
        ),
        message('reasoning', 't1', ''),
        message('him', 'looks tasty', '12:01'),
      ],
      [],
      [localImage],
      sent,
    );
    expect(result.first.attachments, isNotEmpty);
    expect(result.first.text, 'photo.jpg');
    expect(result.first.id, localImage.id);
  });

  test('unmatched local image stays in place among remote turns', () {
    final image = ChatMessage(
      role: 'you',
      text: 'shot.jpg',
      time: '12:01',
      dateKey: '2026-09-13',
      attachments: [
        PickedUploadFile(name: 'shot.jpg', bytes: Uint8List.fromList([9])),
      ],
    );
    final local = [
      message('you', 'hello', '12:00'),
      message('him', 'hi', '12:00'),
      image,
      message('you', 'later', '12:02'),
      message('him', 'ok', '12:02'),
    ];
    final sent = [...local];
    final result = reconcileChatHistory(
      [
        message('you', 'hello', '12:00'),
        message('him', 'hi', '12:00'),
        message('you', 'later', '12:02'),
        message('him', 'ok', '12:02'),
      ],
      [],
      local,
      sent,
    );
    expect(result.map((m) => m.text), [
      'hello',
      'hi',
      'shot.jpg',
      'later',
      'ok',
    ]);
    expect(result[2].attachments, isNotEmpty);
    expect(result[2].id, image.id);
  });

  test('canonical identity matches without guessing body text', () {
    final local = ChatMessage(
      role: 'him',
      text: 'local copy',
      time: '12:00:10',
      dateKey: '2026-09-13',
      turnId: 'turn-same',
    );
    final sent = [local];
    final result = reconcileChatHistory(
      [
        ChatMessage(
          role: 'him',
          text: 'server copy',
          time: '12:00',
          dateKey: '2026-09-13',
          turnId: 'turn-same',
        ),
      ],
      [],
      [local],
      sent,
    );
    expect(sent, isEmpty);
    expect(result.single.id, local.id);
    expect(result.single.text, 'server copy');
    expect(result.single.turnId, 'turn-same');
  });

  // Mirrors the two list filters in ChatController._readHistory. A row with no
  // dateKey is excluded by the `older` filter, so it must stay inside the
  // reconciled window or the next refresh deletes it from the transcript.
  group('undated local rows survive repeated refreshes', () {
    const day = '2026-09-13';

    List<ChatMessage> refreshStep({
      required List<ChatMessage> remote,
      required List<ChatMessage> history,
      required List<ChatMessage> sent,
    }) {
      final reconciled = reconcileChatHistory(
        remote,
        history
            .where((m) => m.dateKey == null || m.dateKey == day)
            .toList(),
        List<ChatMessage>.of(sent),
        sent,
      );
      final older = history
          .where((m) => m.dateKey != null && m.dateKey != day)
          .toList();
      return [...older, ...reconciled];
    }

    test('synchronous reply with no dateKey is not swallowed', () {
      // _appendReply -> _appendSegments builds this with no timestamp.
      final undatedReply = ChatMessage(
        role: 'him',
        text: 'sync http reply',
        time: '12:05',
        turnId: 'turn-http',
      );
      expect(undatedReply.dateKey, isNull);
      final later = ChatMessage(
        role: 'you',
        text: 'later question',
        time: '12:06',
        dateKey: day,
      );
      final sent = [undatedReply, later];
      final remote = [
        ChatMessage(
          role: 'you',
          text: 'later question',
          time: '12:06',
          dateKey: day,
        ),
      ];

      var history = refreshStep(remote: remote, history: [], sent: sent);
      expect(history.map((m) => m.text), ['sync http reply', 'later question']);

      // The server still has not flushed the reply into the chat log.
      history = refreshStep(remote: remote, history: history, sent: sent);
      expect(history.map((m) => m.text), ['sync http reply', 'later question']);

      history = refreshStep(remote: remote, history: history, sent: sent);
      expect(
        history.map((m) => m.text),
        ['sync http reply', 'later question'],
        reason: 'refresh must be idempotent, neither dropping nor duplicating',
      );
    });

    test('undated upload preview keeps its attachment across refreshes', () {
      final upload = ChatMessage(
        role: 'you',
        text: '📎 photo.jpg',
        time: '现在',
        turnId: 'turn-img',
        attachments: [
          PickedUploadFile(name: 'photo.jpg', bytes: Uint8List.fromList([1])),
        ],
      );
      expect(upload.dateKey, isNull);
      final sent = [upload];
      final remote = [
        ChatMessage(
          role: 'you',
          text: '📎 photo.jpg\nA bowl of rice',
          time: '12:00',
          dateKey: day,
          turnId: 'turn-img',
        ),
      ];

      var history = refreshStep(remote: remote, history: [], sent: sent);
      expect(history.single.attachments, isNotEmpty);
      expect(history.single.text, '📎 photo.jpg');

      history = refreshStep(remote: remote, history: history, sent: sent);
      expect(
        history.single.attachments,
        isNotEmpty,
        reason: 'the image bubble must not degrade to the log text row',
      );
      expect(history.single.text, '📎 photo.jpg');
    });

    // The transcript the user sees is history followed by sent
    // (ChatWidgets indexes both lists), so a sticker parked in sent is still
    // on screen even though reconcile never promotes it into history.
    test('undated sticker bubble stays on screen across refreshes', () {
      final sticker = ChatMessage(
        role: 'him',
        text: '',
        time: '12:05',
        sticker: const StickerPayload(
          emotion: 'happy',
          dataUrl: 'data:image/png;base64,AA',
        ),
      );
      final sent = [sticker];
      var history = refreshStep(remote: [], history: [], sent: sent);
      expect([...history, ...sent].any((m) => m.sticker != null), isTrue);
      history = refreshStep(remote: [], history: history, sent: sent);
      expect([...history, ...sent].any((m) => m.sticker != null), isTrue);
    });
  });

  // 24/B + 24/C: an unmatched local row is kept rather than dropped, and a
  // matched rich bubble keeps its local payload instead of the flattened log
  // line. Each case refreshes twice to prove idempotence.
  group('refresh neither swallows nor degrades local rows', () {
    // Rows reach `history` once a refresh has promoted them; from there on it
    // is the `previous` path that must not drop or flatten them. A live row
    // that has not matched yet simply stays in `sent`, still on screen.
    List<ChatMessage> refresh(
      List<ChatMessage> remote,
      List<ChatMessage> history, [
      List<ChatMessage>? sent,
    ]) {
      final live = sent ?? <ChatMessage>[];
      return reconcileChatHistory(
        remote,
        history,
        List<ChatMessage>.of(live),
        live,
      );
    }

    test('polled reply missing from the remote log survives, once', () {
      final question = message('you', 'are you there', '12:00');
      final reply = ChatMessage(
        role: 'him',
        text: 'polled reply',
        time: '12:01',
        dateKey: '2026-09-13',
        turnId: 'turn-poll',
        retainOnRefresh: true,
      );
      final lagging = [message('you', 'are you there', '12:00')];

      var history = refresh(lagging, [question, reply]);
      expect(history.map((m) => m.text), ['are you there', 'polled reply']);
      history = refresh(lagging, history);
      expect(
        history.map((m) => m.text),
        ['are you there', 'polled reply'],
        reason: 'repeat refreshes must not accumulate copies',
      );

      // The backend finally flushes the reply into the chat log.
      final flushed = [
        message('you', 'are you there', '12:00'),
        ChatMessage(
          role: 'him',
          text: 'polled reply',
          time: '12:01',
          dateKey: '2026-09-13',
          turnId: 'turn-poll',
        ),
      ];
      history = refresh(flushed, history);
      expect(history.map((m) => m.text), ['are you there', 'polled reply']);
      expect(history.where((m) => m.text == 'polled reply'), hasLength(1));
    });

    test('sticker bubble stays through refreshes and is not duplicated', () {
      const payload = StickerPayload(
        emotion: 'happy',
        dataUrl: 'data:image/png;base64,AA',
      );
      final sticker = ChatMessage(
        role: 'him',
        text: '',
        time: '12:05',
        dateKey: '2026-09-13',
        turnId: 'turn-sticker',
        sticker: payload,
        retainOnRefresh: true,
      );

      var history = refresh([], [sticker]);
      expect(history.single.sticker, payload);
      history = refresh([], history);
      expect(history.single.sticker, payload);
      expect(history, hasLength(1));

      // Once the log carries the turn, the sticker matches it instead of
      // being inserted a second time.
      final remote = [
        ChatMessage(
          role: 'him',
          text: '[表情]',
          time: '12:05',
          dateKey: '2026-09-13',
          turnId: 'turn-sticker',
        ),
      ];
      history = refresh(remote, history);
      expect(history, hasLength(1));
      expect(history.single.sticker, payload);
      expect(history.single.text, '', reason: 'local payload wins over log text',
      );
    });

    test('reply quote and inline display survive a matched refresh', () {
      final quoted = ChatMessage(
        role: 'you',
        text: 'about that',
        time: '12:00:10',
        dateKey: '2026-09-13',
        turnId: 'turn-quote',
        quotedText: 'earlier line',
        quotedLabel: 'reply',
        retainOnRefresh: true,
      );
      final inline = ChatMessage(
        role: 'him',
        text: '(smiles) sure',
        displayText: 'sure',
        time: '12:00:11',
        dateKey: '2026-09-13',
        turnId: 'turn-quote',
        retainOnRefresh: true,
      );
      final remote = [
        ChatMessage(
          role: 'you',
          text: 'about that',
          time: '12:00',
          dateKey: '2026-09-13',
          turnId: 'turn-quote',
        ),
        // The assistant event has not landed, so the projection is null.
        ChatMessage(
          role: 'him',
          text: '(smiles) sure',
          time: '12:00',
          dateKey: '2026-09-13',
          turnId: 'turn-quote',
        ),
      ];

      var history = refresh(remote, [quoted, inline]);
      expect(history.first.quotedText, 'earlier line');
      expect(history.first.quotedLabel, 'reply');
      expect(history.last.displayText, 'sure');

      history = refresh(remote, history);
      expect(history.first.quotedText, 'earlier line');
      expect(
        history.last.displayText,
        'sure',
        reason: 'a null remote projection must not erase inline display',
      );
    });

    test('a cleaned remote projection does not replace local inline display', () {
      final inline = ChatMessage(
        role: 'him',
        text: '(smiles) sure',
        displayText: 'sure',
        time: '12:00:11',
        dateKey: '2026-09-13',
        turnId: 'turn-proj',
        retainOnRefresh: true,
      );
      final result = refresh([
        ChatMessage(
          role: 'him',
          text: '(smiles) sure',
          displayText: 'smiles sure',
          time: '12:00',
          dateKey: '2026-09-13',
          turnId: 'turn-proj',
        ),
      ], [inline],
        );
      expect(result.single.displayText, 'sure');
      expect(result.single.text, '(smiles) sure');
    },
    );

    test('an ambiguous file bubble is kept instead of collapsed to a log row', () {
      final upload = ChatMessage(
        role: 'you',
        text: '📎 notes.pdf',
        time: '12:00:10',
        dateKey: '2026-09-13',
        turnId: 'turn-file',
        attachments: [
          PickedUploadFile(name: 'notes.pdf', bytes: Uint8List.fromList([1])),
        ],
        retainOnRefresh: true,
      );
      // Two same-minute user rows, neither carrying the canonical turn: the
      // preview cannot be attributed, so it must stay a file bubble.
      final remote = [
        message('you', '📎 notes.pdf', '12:00'),
        message('you', '📎 notes.pdf', '12:00'),
      ];
      final history = refresh(remote, [upload]);
      expect(history, hasLength(3));
      expect(
        history.where((m) => m.attachments.isNotEmpty),
        hasLength(1),
        reason: 'the local bubble keeps its attachment rather than vanishing',
      );
    },
    );
  });

  test('legacy unmatched text still uses clock fallback without inventing ids', () {
    final local = message('him', 'same minute', '12:00:10');
    final sent = [local];
    final result = reconcileChatHistory(
      [message('him', 'same minute', '12:00')],
      [],
      [local],
      sent,
    );
    expect(sent, isEmpty);
    expect(result.single.id, local.id);
    expect(result.single.turnId, isNull);
  },
  );
}
