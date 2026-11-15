import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/models/chat_history_display.dart';
import 'package:presencekit_mobile/models/app_models.dart';

void main() {
  test(
    '57: terminal footer whitespace and compact quote variants stay hidden',
    () {
      for (final footer in [
        '\n> speaker:user turn_id:fixture-turn\n\n',
        '\r\n>speaker:user turn_id:fixture-turn  \r\n',
        '\n> speaker:user turn_id:fixture-turn\t\n',
      ]) {
        expect(historyVisibleText('original$footer'), 'original');
      }
      expect(historyVisibleText('>speaker:user turn_id:fixture-turn\n'), '');
      expect(
        historyVisibleText('ordinary >speaker:user example'),
        'ordinary >speaker:user example',
      );
    },
  );
  test('history JSON hides writer footer and retains canonical identity', () {
    final entry = ChatLogEntry.fromJson({
      'time': '12:00',
      'turn_id': 'canonical',
      'user': 'question\n> speaker:user turn_id:user-turn',
      'assistant': 'answer\n> speaker:assistant turn_id:canonical',
      'assistant_display_text':
          'display\n> speaker:assistant turn_id:canonical',
    });
    expect(entry.user, 'question');
    expect(entry.assistant, 'answer');
    expect(entry.assistantDisplayText, 'display');
    expect(entry.turnId, 'canonical');
    expect(
      historyVisibleText(
        'voice\n> speaker:user source:mobile modality:voice asr_low:1',
      ),
      'voice',
    );
    expect(historyVisibleText('text\n> speaker:user'), 'text');
  });
  test('terminal writer footer is hidden without dropping normal quotes', () {
    expect(
      historyVisibleText(
        '我觉得你好像有点不一样了\n> speaker:user turn_id:fixture-user-turn',
      ),
      '我觉得你好像有点不一样了',
    );
    expect(
      historyVisibleText('body\n> speaker:user turn_id:inside\nmore'),
      'body\n> speaker:user turn_id:inside\nmore',
    );
  });
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
