import 'reference_typography.dart';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../models/ui_layout.dart';
import 'reference_art.dart';

class ReferenceChatIntro extends StatelessWidget {
  const ReferenceChatIntro({
    super.key,
    required this.c,
    required this.layout,
    required this.name,
  });
  final YxPalette c;
  final DailyLayout layout;
  final String name;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final paper = layout == DailyLayout.letter;
    final title = paper
        ? l.referenceLetterTitle
        : layout == DailyLayout.noir
        ? l.referenceNoirTitle
        : l.referenceReverieTitle;
    final lines = title.split('\n');
    return Padding(
      padding: const EdgeInsets.only(top: 9, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (paper) ...[
            Text(
              MaterialLocalizations.of(context).formatFullDate(DateTime.now()),
              style: referenceSerif(c, 10, color: c.ink3),
            ),
            const SizedBox(height: 17),
          ],
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: EdgeInsets.only(
                left: i == 1 && layout != DailyLayout.noir
                    ? paper
                          ? 35
                          : 24
                    : 0,
              ),
              child: Text(
                lines[i],
                style: referenceSerif(
                  c,
                  paper ? 40 : 29,
                  color: !paper && i == 1 ? c.character : c.ink1,
                ).copyWith(height: paper ? 1.35 : 1.6, letterSpacing: 2),
              ),
            ),
          if (paper) ...[
            const SizedBox(height: 19),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: c.surfaceEdge),
                ),
              ),
              child: Text(name, style: referenceSerif(c, 11, color: c.ink2)),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: Text(l.referenceSalutation, style: referenceSerif(c, 15)),
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(48),
                    ),
                    child: ReferenceLandscape(c: c, height: 105),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
