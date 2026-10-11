import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/messenger_display.dart';

ChatMessage row(
  String clock, {
  String day = '2026-09-27',
  String role = 'him',
  String text = 'text',
  String? quote,
}) => ChatMessage(
  role: role,
  text: text,
  time: clock,
  dateKey: day,
  quotedText: quote,
);

void main() {
  test(
    'time marker starts a conversation and appears at ten minutes, not nine',
    () {
      final first = row('12:34');
      expect(messengerShowsTimestamp(first, null), isTrue);
      expect(messengerShowsTimestamp(row('12:43'), first), isFalse);
      expect(messengerShowsTimestamp(row('12:44'), first), isTrue);
      expect(messengerShowsTimestamp(row('12:45'), row('12:43')), isFalse);
      expect(messengerShowsTimestamp(row('12:33'), first), isFalse);
    },
  );
  test(
    'midnight and older history use the message date instead of load time',
    () {
      final previous = row('23:55');
      expect(
        messengerShowsTimestamp(row('00:04', day: '2026-09-28'), previous),
        isFalse,
      );
      expect(
        messengerShowsTimestamp(row('00:05', day: '2026-09-28'), previous),
        isTrue,
      );
      expect(
        messengerMessageTime(row('00:05', day: '2026-09-28')),
        DateTime(2026, 9, 28, 0, 5),
      );
    },
  );
  test(
    'quote sender requires evidence, ambiguous identical text stays unnamed',
    () {
      final quote = row('12:44', quote: 'source');
      expect(
        messengerQuoteRole(quote, [row('12:34', text: 'source', role: 'you')]),
        'you',
      );
      expect(
        messengerQuoteRole(quote, [row('12:34', text: 'source', role: 'him')]),
        'him',
      );
      expect(
        messengerQuoteRole(quote, [
          row('12:34', text: 'source', role: 'you'),
          row('12:35', text: 'source'),
        ]),
        isNull,
      );
      expect(messengerQuoteRole(quote, []), isNull);
    },
  );
}
