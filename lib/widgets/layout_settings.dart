import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../models/ui_layout.dart';
import 'common_widgets.dart';

String dailyLayoutLabel(AppLocalizations l, DailyLayout value) =>
    switch (value) {
      DailyLayout.classic => l.layoutClassic,
      DailyLayout.letter => l.layoutLetter,
      DailyLayout.reverie => l.layoutReverie,
      DailyLayout.noir => l.layoutNoir,
      DailyLayout.messenger => l.layoutMessenger,
    };
String dreamLayoutLabel(AppLocalizations l, DreamLayout value) =>
    value == DreamLayout.classic ? l.layoutClassic : l.layoutMoonlit;

class LayoutSettings extends StatelessWidget {
  const LayoutSettings({
    super.key,
    required this.c,
    required this.daily,
    required this.dream,
    required this.onDaily,
    required this.onDream,
  });
  final YxPalette c;
  final DailyLayout daily;
  final DreamLayout dream;
  final ValueChanged<DailyLayout> onDaily;
  final ValueChanged<DreamLayout> onDream;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        ListTile(
          title: Text(l.dailyInterface, style: serif(c, 16)),
          trailing: DropdownButton<DailyLayout>(
            value: daily,
            dropdownColor: c.surfaceSoft,
            style: serif(c, 14),
            underline: const SizedBox.shrink(),
            items: DailyLayout.values
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(dailyLayoutLabel(l, v)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onDaily(v);
            },
          ),
        ),
        ListTile(
          title: Text(l.dreamInterface, style: serif(c, 16)),
          trailing: DropdownButton<DreamLayout>(
            value: dream,
            dropdownColor: c.surfaceSoft,
            style: serif(c, 14),
            underline: const SizedBox.shrink(),
            items: DreamLayout.values
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(dreamLayoutLabel(l, v)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onDream(v);
            },
          ),
        ),
      ],
    );
  }
}
