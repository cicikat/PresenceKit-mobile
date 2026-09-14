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
        PickedUploadFile(name: 'photo.jpg', bytes: Uint8List.fromList([1, 2, 3])),
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
        PickedUploadFile(name: 'photo.jpg', bytes: Uint8List.fromList([1, 2, 3])),
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
}
