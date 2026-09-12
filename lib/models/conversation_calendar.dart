class ConversationDay {
  ConversationDay(this.data);
  final Map<String, dynamic> data;
  String get date => data['date'] as String;
  String get coverage => data['coverage'] as String? ?? 'unavailable';
  int? value(String key) =>
      coverage == 'future' ? null : (data[key] as num?)?.toInt();
  int? get rounds => value('chat_rounds');
}

class ConversationCalendar {
  ConversationCalendar.fromJson(Map<String, dynamic> json)
    : days = (json['days'] as List)
          .map((e) => ConversationDay(Map<String, dynamic>.from(e as Map)))
          .toList(),
      start = json['start'] as String,
      end = json['end'] as String,
      character = json['char_id'] as String,
      partial = json['totals_partial'] == true;
  final List<ConversationDay> days;
  final String start, end, character;
  final bool partial;
  int? total(String key) {
    final known = days.map((d) => d.value(key)).whereType<int>();
    return known.isEmpty ? null : known.fold<int>(0, (a, b) => a + b);
  }
}
