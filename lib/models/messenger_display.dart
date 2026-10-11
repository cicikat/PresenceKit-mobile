import 'app_models.dart';

DateTime messengerMessageTime(ChatMessage message) {
  final clock = RegExp(r'(\d{2}):(\d{2})(?::\d{2})?').firstMatch(message.time);
  if (clock == null) return message.timestamp.toLocal();
  final date =
      DateTime.tryParse(message.dateKey ?? '') ?? message.timestamp.toLocal();
  return DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(clock.group(1)!),
    int.parse(clock.group(2)!),
  );
}

bool messengerShowsTimestamp(ChatMessage message, ChatMessage? previous) =>
    previous == null ||
    messengerMessageTime(message).difference(messengerMessageTime(previous)) >=
        const Duration(minutes: 10);

/// Prefer explicit reply identity; legacy text alone only identifies an author
/// when all matching preceding messages belong to the same role.
String? messengerQuoteRole(
  ChatMessage message,
  Iterable<ChatMessage> preceding,
) {
  final id = message.retryReplyTo?.messageId;
  if (id != null && id.endsWith(':user')) return 'you';
  if (id != null && id.endsWith(':assistant')) return 'him';
  final matches = preceding.where(
    (row) =>
        row.text == message.quotedText &&
        (row.role == 'you' || row.role == 'him'),
  );
  final roles = matches.map((row) => row.role).toSet();
  return roles.length == 1 ? roles.single : null;
}
