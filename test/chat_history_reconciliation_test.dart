import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_history_reconciliation.dart';
import 'package:presencekit_mobile/models/app_models.dart';

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
      expect(result.map((m) => m.text), ['sent', 't1', 'reply']);
      expect(sent.map((m) => m.id), [failed.id, pending.id]);
      expect(sent.first.failed, isTrue);
    },
  );
}
