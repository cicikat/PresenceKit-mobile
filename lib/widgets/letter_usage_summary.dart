import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import 'reference_typography.dart';
import 'reference_art.dart';

/// A letterhead for the existing calendar, with actual streak/coverage data.
class LetterUsageSummary extends StatelessWidget {
  const LetterUsageSummary({
    super.key,
    required this.c,
    required this.name,
    required this.streak,
    required this.lowerBound,
  });
  final YxPalette c;
  final String name;
  final int? streak;
  final bool lowerBound;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        border: Border.all(color: c.surfaceEdge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.referenceUsageTab,
                      style: referenceUiText(c, 10, color: c.ink3, spacing: 2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMonthYear(DateTime.now()),
                      style: referenceUiText(c, 11, color: c.ink2),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 58,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: c.character.withValues(alpha: .55)),
                ),
                child: ReferenceLandscape(c: c, height: 50),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            l.referenceUsageTitle,
            style: referenceSerif(c, 27, height: 1.5),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: c.surfaceEdge),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.local_post_office_outlined,
                size: 19,
                color: c.character,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  streak == null
                      ? l.calendarTogether(name)
                      : l.calendarStreak(
                          name,
                          '${lowerBound ? '≥ ' : ''}$streak',
                        ),
                  style: referenceSerif(c, 16, height: 1.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.calendarStreakHelp,
            style: referenceUiText(c, 10, color: c.ink3, height: 1.7),
          ),
        ],
      ),
    );
  }
}
