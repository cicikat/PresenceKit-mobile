import 'package:flutter/foundation.dart';
import '../models/conversation_calendar.dart';
import '../services/backend_client.dart';

class ConversationCalendarController extends ChangeNotifier {
  ConversationCalendarController({required this.backend, required this.token});
  final BackendClient Function() backend;
  final String Function() token;
  String period = 'month';
  DateTime? anchor;
  ConversationCalendar? calendar;
  ConversationDay? selected;
  String? error;
  bool loading = false;
  int _generation = 0;
  bool _disposed = false;
  int? streak;
  bool streakLowerBound = false;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> load({String? period, DateTime? date}) async {
    if (period != null) this.period = period;
    if (date != null) anchor = date;
    final generation = ++_generation;
    loading = true;
    error = null;
    calendar = null;
    selected = null;
    streak = null;
    notifyListeners();
    try {
      final client = backend();
      final credential = token();
      final result = await client.fetchConversationCalendar(
        token: credential,
        period: this.period,
        date: anchor == null ? null : dateKey(anchor!),
      );
      if (_disposed || generation != _generation) return;
      calendar = result;
      selected = result.days.firstOrNull;
      // Ask the server for its current day; do not re-bucket server dates locally.
      final today = await client.fetchConversationCalendar(
        token: credential,
        period: 'day',
        character: result.character,
      );
      if (_disposed || generation != _generation) return;
      final parsed = DateTime.parse(today.end);
      final end = DateTime.utc(parsed.year, parsed.month, parsed.day);
      final history = await client.fetchConversationCalendar(
        token: credential,
        character: result.character,
        start: dateKey(end.subtract(const Duration(days: 365))),
        end: today.end,
      );
      if (_disposed || generation != _generation) return;
      var index = history.days.length - 1;
      if (index >= 0 && history.days[index].rounds == 0) index--;
      var count = 0;
      while (index >= 0 && (history.days[index].rounds ?? 0) > 0) {
        count++;
        index--;
      }
      streak = count == 0 && index >= 0 && history.days[index].rounds == null
          ? null
          : count;
      streakLowerBound =
          index < 0 ||
          (index >= 0 &&
              (history.days[index].rounds == null ||
                  history.days[index].coverage != 'complete'));
      calendar = result;
      selected =
          result.days.where((d) => d.date == today.end).firstOrNull ??
          result.days.firstOrNull;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = e is BackendException ? e.message : e.toString();
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void select(ConversationDay day) {
    selected = day;
    notifyListeners();
  }

  void move(int direction) {
    final parsed =
        anchor ?? DateTime.tryParse(calendar?.start ?? '') ?? DateTime.now();
    final current = DateTime.utc(parsed.year, parsed.month, parsed.day);
    final next = switch (period) {
      'year' => DateTime(current.year + direction, 1, 1),
      'month' => DateTime(current.year, current.month + direction, 1),
      'week' => current.add(Duration(days: 7 * direction)),
      _ => current.add(Duration(days: direction)),
    };
    load(date: next);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
