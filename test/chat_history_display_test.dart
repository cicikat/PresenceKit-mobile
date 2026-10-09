import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/models/chat_history_display.dart';

void main() {
  test(
    'current exact and unverified reply envelopes recover multiline quotes',
    () {
      for (final metadata in [
        '作者=角色，时间=2026-10-10T12:00:00+08:00，message_id=turn:assistant',
        '作者=用户，时间=2026-10-10T12:00:00+08:00，message_id=turn:user',
        '旧引用无稳定锚点，作者未经核验，客户端时间=2026-10-10T12:00:00+08:00',
      ]) {
        final display = historyUserDisplay(
          '用户引用回复：$metadata，原文「first\n<b>second</b>」：my\n\nreply',
        );
        expect(display.quote, 'first\n<b>second</b>');
        expect(display.text, 'my\n\nreply');
      }
    },
  );
  test('legacy envelope recovers without interpreting ordinary quotes', () {
    expect(historyUserDisplay('用户回复了你今天 12:00发送的这条消息「hello」：yes'), (
      text: 'yes',
      quote: 'hello',
    ));
    for (final text in [
      'first\n\nsecond',
      '原文「quoted」：body',
      '用户引用回复：not a server envelope，原文「hello」：body',
    ]) {
      expect(historyUserDisplay(text), (text: text, quote: null));
    }
  });
}
