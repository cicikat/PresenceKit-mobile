import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/conversation_calendar_controller.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../models/conversation_calendar.dart';
import '../services/backend_client.dart';
import 'common_widgets.dart';

const calendarColors = <String, Color>{
  'jade': Color(0xFF368568),
  'blue': Color(0xFF477EBA),
  'rose': Color(0xFFB56082),
  'amber': Color(0xFFB78135),
};

class CalendarPaletteSetting extends StatelessWidget {
  const CalendarPaletteSetting({
    super.key,
    required this.c,
    required this.value,
    required this.onChanged,
  });
  final YxPalette c;
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [
      l.calendarJade,
      l.calendarBlue,
      l.calendarRose,
      l.calendarAmber,
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.calendarPalette, style: serif(c, 16)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in calendarColors.entries.indexed)
                ChoiceChip(
                  label: Text(labels[entry.$1]),
                  avatar: CircleAvatar(
                    backgroundColor: entry.$2.value,
                    radius: 7,
                  ),
                  selected: value == entry.$2.key,
                  onSelected: (_) => onChanged(entry.$2.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ConversationCalendarPage extends StatefulWidget {
  const ConversationCalendarPage({
    super.key,
    required this.c,
    required this.palette,
    required this.name,
    required this.backend,
    required this.token,
    required this.onBack,
  });
  final YxPalette c;
  final String palette, name, token;
  final BackendClient backend;
  final VoidCallback onBack;
  @override
  State<ConversationCalendarPage> createState() =>
      _ConversationCalendarPageState();
}

class _ConversationCalendarPageState extends State<ConversationCalendarPage> {
  late final controller = ConversationCalendarController(
    backend: () => widget.backend,
    token: () => widget.token,
  );
  @override
  void initState() {
    super.initState();
    controller.load();
  }

  @override
  void didUpdateWidget(covariant ConversationCalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backend != widget.backend ||
        oldWidget.token != widget.token ||
        oldWidget.name != widget.name) {
      controller.load();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final accent = calendarColors[widget.palette] ?? calendarColors['jade']!;
    final dark = c.surface.computeLuminance() < .4;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: c.surface,
      onSurface: c.ink1,
    );
    return Theme(
      data: ThemeData(useMaterial3: true, colorScheme: scheme),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final l = context.l10n;
          final data = controller.calendar;
          final labels = [
            l.calendarDay,
            l.calendarWeek,
            l.calendarMonth,
            l.calendarYear,
          ];
          return Column(
            children: [
              PageHeader(
                c: c,
                title: l.calendarTitle,
                trailing: '',
                eyebrow: widget.name,
                onBack: widget.onBack,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => controller.load(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.alphaBlend(
                                accent.withValues(alpha: dark ? .3 : .15),
                                c.surface,
                              ),
                              c.surfaceSoft,
                            ],
                          ),
                          border: Border.all(
                            color: accent.withValues(alpha: .25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.auto_awesome_outlined,
                              color: scheme.primary,
                              size: 25,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              controller.streak == null
                                  ? l.calendarTogether(widget.name)
                                  : l.calendarStreak(
                                      widget.name,
                                      '${controller.streakLowerBound ? '≥ ' : ''}${controller.streak}',
                                    ),
                              style: serif(c, 24, weight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l.calendarStreakHelp,
                              style: TextStyle(color: c.ink2, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      SegmentedButton<String>(
                        segments: [
                          for (final entry in [
                            'day',
                            'week',
                            'month',
                            'year',
                          ].indexed)
                            ButtonSegment(
                              value: entry.$2,
                              label: Text(labels[entry.$1]),
                            ),
                        ],
                        selected: {controller.period},
                        onSelectionChanged: (values) =>
                            controller.load(period: values.first),
                        showSelectedIcon: false,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          IconButton(
                            onPressed: controller.loading
                                ? null
                                : () => controller.move(-1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Text(
                              data == null
                                  ? l.calendarTitle
                                  : '${data.start} — ${data.end}',
                              textAlign: TextAlign.center,
                              style: mono(c, 12),
                            ),
                          ),
                          IconButton(
                            onPressed: controller.loading
                                ? null
                                : () => controller.move(1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                          IconButton(
                            tooltip: l.refreshAction,
                            onPressed: controller.loading
                                ? null
                                : () => controller.load(),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      if (controller.loading)
                        const Padding(
                          padding: EdgeInsets.all(36),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (controller.error != null) ...[
                        Text(
                          controller.error!,
                          style: TextStyle(color: scheme.error),
                        ),
                        TextButton(
                          onPressed: () => controller.load(),
                          child: Text(l.refreshAction),
                        ),
                      ],
                      if (data != null) ...[
                        _Heatmap(
                          c: c,
                          accent: accent,
                          data: data,
                          period: controller.period,
                          selected: controller.selected?.date,
                          onSelect: (day) {
                            controller.select(day);
                            showModalBottomSheet<void>(
                              context: context,
                              showDragHandle: true,
                              isScrollControlled: true,
                              backgroundColor: c.surface,
                              builder: (_) => SafeArea(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(day.date, style: serif(c, 24)),
                                      const SizedBox(height: 12),
                                      Text(
                                        day.coverage == 'complete' &&
                                                (day.value(
                                                          'usage_missing_calls',
                                                        ) ??
                                                        0) ==
                                                    0
                                            ? l.calendarComplete
                                            : l.calendarPartial,
                                        style: TextStyle(color: c.ink2),
                                      ),
                                      const SizedBox(height: 20),
                                      _Metrics(
                                        c: c,
                                        accent: scheme.primary,
                                        value: day.value,
                                        details: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(l.calendarLess, style: mono(c, 11)),
                            for (var i = 0; i < 5; i++)
                              Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: Color.lerp(
                                    c.surfaceSoft,
                                    accent,
                                    i / 4,
                                  ),
                                  border: Border.all(color: c.surfaceEdge),
                                ),
                              ),
                            Text(l.calendarMore, style: mono(c, 11)),
                            Text(' · ${l.calendarUnknown}', style: mono(c, 11)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(l.calendarPeriodTotals, style: serif(c, 17)),
                        const SizedBox(height: 10),
                        _Metrics(
                          c: c,
                          accent: scheme.primary,
                          value: data.total,
                        ),
                        if (data.partial)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              l.calendarPartial,
                              style: TextStyle(color: c.ink2, height: 1.5),
                            ),
                          ),
                        if (controller.selected case final day?) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: c.surfaceSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: accent.withValues(alpha: .4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.event_outlined,
                                      color: scheme.primary,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(day.date, style: serif(c, 20)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  day.coverage == 'future'
                                      ? l.calendarFuture
                                      : day.coverage == 'complete' &&
                                            (day.value('usage_missing_calls') ??
                                                    0) ==
                                                0
                                      ? l.calendarComplete
                                      : l.calendarPartial,
                                  style: TextStyle(color: c.ink2, height: 1.5),
                                ),
                                const SizedBox(height: 16),
                                _Metrics(
                                  c: c,
                                  accent: scheme.primary,
                                  value: day.value,
                                  details: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          l.calendarMetricHelp,
                          style: TextStyle(
                            color: c.ink2,
                            fontSize: 12,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({
    required this.c,
    required this.accent,
    required this.value,
    this.details = false,
  });
  final YxPalette c;
  final Color accent;
  final int? Function(String) value;
  final bool details;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = {
      'chat_rounds': l.calendarRounds,
      'total_tokens': l.calendarTokens,
      'tool_calls': l.calendarTools,
      'image_views': l.calendarImages,
      if (details) ...{
        'input_tokens': l.calendarInput,
        'output_tokens': l.calendarOutput,
        'model_calls': l.calendarModels,
        'usage_missing_calls': l.calendarMissing,
      },
    };
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 12,
        runSpacing: 16,
        children: [
          for (final entry in labels.entries)
            SizedBox(
              width: (constraints.maxWidth - 12) / 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value(entry.key)?.toString() ?? '—',
                    style: TextStyle(
                      color: accent,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    entry.value,
                    style: TextStyle(color: c.ink2, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({
    required this.c,
    required this.accent,
    required this.data,
    required this.period,
    required this.selected,
    required this.onSelect,
  });
  final YxPalette c;
  final Color accent;
  final ConversationCalendar data;
  final String period;
  final String? selected;
  final ValueChanged<ConversationDay> onSelect;
  @override
  Widget build(BuildContext context) {
    final peak = data.days.fold<int>(1, (n, d) => math.max(n, d.rounds ?? 0));
    Widget cell(ConversationDay day, {bool compact = false}) {
      final count = day.rounds;
      final future = day.coverage == 'future';
      final strength = count == null || count == 0
          ? 0.0
          : .25 + .75 * math.sqrt(count / peak);
      final fill = Color.lerp(c.surfaceSoft, accent, strength)!;
      final ink = fill.computeLuminance() > .4 ? Colors.black87 : Colors.white;
      return Semantics(
        button: !future,
        selected: selected == day.date,
        label:
            '${day.date}, ${context.l10n.calendarRounds}: ${count ?? context.l10n.calendarUnknown}',
        child: Tooltip(
          message: '${day.date} · ${count ?? '—'}',
          child: InkWell(
            onTap: future ? null : () => onSelect(day),
            borderRadius: BorderRadius.circular(compact ? 3 : 9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: future ? c.surface : fill,
                borderRadius: BorderRadius.circular(compact ? 3 : 9),
                border: Border.all(
                  color: selected == day.date ? c.ink1 : c.surfaceEdge,
                  width: selected == day.date ? 2 : 1,
                ),
              ),
              child: compact
                  ? (count == null && !future
                        ? Text('·', style: TextStyle(color: c.ink2))
                        : null)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${DateTime.parse(day.date).day}',
                          style: TextStyle(
                            color: future ? c.ink3 : ink,
                            fontSize: 13,
                          ),
                        ),
                        if (period == 'day' || period == 'week')
                          Text(
                            count?.toString() ?? '—',
                            style: TextStyle(color: ink, fontSize: 11),
                          ),
                        if (count == null && !future)
                          Text('—', style: TextStyle(color: ink, fontSize: 9)),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    Widget month(List<ConversationDay> days, {bool compact = false}) {
      if (days.isEmpty) return const SizedBox.shrink();
      final offset = DateTime.parse(days.first.date).weekday - 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          crossAxisSpacing: compact ? 3 : 5,
          mainAxisSpacing: compact ? 3 : 5,
        ),
        itemCount: days.length + offset,
        itemBuilder: (context, i) => i < offset
            ? const SizedBox.shrink()
            : cell(days[i - offset], compact: compact),
      );
    }

    if (period == 'year') {
      return LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 16,
          runSpacing: 18,
          children: [
            for (var m = 1; m <= 12; m++)
              SizedBox(
                width: (constraints.maxWidth - 16) / 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MaterialLocalizations.of(context).formatMonthYear(
                        DateTime(DateTime.parse(data.start).year, m),
                      ),
                      style: mono(c, 11),
                    ),
                    const SizedBox(height: 6),
                    month(
                      data.days
                          .where((d) => DateTime.parse(d.date).month == m)
                          .toList(),
                      compact: true,
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    if (period == 'day') {
      return SizedBox(height: 100, child: cell(data.days.first));
    }
    final weekdays = MaterialLocalizations.of(context).narrowWeekdays;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 1; i <= 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    weekdays[i % 7],
                    textAlign: TextAlign.center,
                    style: mono(c, 11),
                  ),
                ),
              ),
          ],
        ),
        month(data.days),
      ],
    );
  }
}
