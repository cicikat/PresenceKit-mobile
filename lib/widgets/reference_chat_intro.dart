import 'reference_typography.dart';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../models/ui_layout.dart';

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
    final noir = layout == DailyLayout.noir;
    return Padding(
      padding: EdgeInsets.only(
        top: paper
            ? 23
            : noir
            ? 21
            : 22,
        bottom: paper ? 15 : 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MaterialLocalizations.of(context).formatFullDate(DateTime.now()),
            style: referenceUiText(c, paper ? 9 : 8, color: c.ink3, spacing: 1),
          ),
          SizedBox(
            height: paper
                ? 17
                : noir
                ? 21
                : 14,
          ),
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: EdgeInsets.only(
                left: i == 1 && !noir
                    ? paper
                          ? 35
                          : 24
                    : 0,
              ),
              child: Text(
                lines[i],
                style: noir
                    ? referenceUiText(
                        c,
                        29,
                        color: i == 1 ? c.character : c.ink1,
                        height: 1.65,
                        spacing: -1,
                      ).copyWith(fontWeight: FontWeight.w600)
                    : referenceSerif(
                        c,
                        paper ? 40 : 29,
                        color: !paper && i == 1 ? c.character : c.ink1,
                        height: paper ? 1.35 : 1.6,
                        spacing: 2,
                      ),
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
              child: Row(
                children: [
                  Text(
                    l.referenceChatTab,
                    style: referenceSerif(
                      c,
                      8,
                      latin: true,
                      color: c.ink3,
                      spacing: 2,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: referenceSerif(c, 10, color: c.ink2, spacing: 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 27),
            Text(
              l.referenceSalutation,
              style: referenceSerif(c, 15, height: 1.2),
            ),
          ] else ...[
            const SizedBox(height: 7),
            Text(
              l.referenceWindowSubtitle,
              style: referenceUiText(c, 10, color: c.ink3, spacing: 1),
            ),
          ],
        ],
      ),
    );
  }
}
