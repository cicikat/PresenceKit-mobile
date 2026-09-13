import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import 'common_widgets.dart';
import 'settings_editor_widgets.dart';
import 'theme_widgets.dart';

class DreamAppearanceSettings extends StatelessWidget {
  const DreamAppearanceSettings({
    super.key,
    required this.c,
    required this.prefs,
    required this.onPrefs,
  });
  final YxPalette c;
  final YxPrefs prefs;
  final ValueChanged<YxPrefs> onPrefs;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final entries = [
      (
        l.dreamNarrationColorLabel,
        l.dreamNarrationSize,
        l.dreamPreviewNarration,
        prefs.dreamNarrationColor ?? c.ink3.toARGB32(),
        prefs.dreamNarrationSize,
        (Color v) => onPrefs(prefs.copyWith(dreamNarrationColor: v.toARGB32())),
        (double v) => onPrefs(prefs.copyWith(dreamNarrationSize: v)),
      ),
      (
        l.dreamChatColorLabel,
        l.dreamChatSize,
        l.dreamPreviewChat,
        prefs.dreamChatColor ?? c.ink1.toARGB32(),
        prefs.dreamChatSize,
        (Color v) => onPrefs(prefs.copyWith(dreamChatColor: v.toARGB32())),
        (double v) => onPrefs(prefs.copyWith(dreamChatSize: v)),
      ),
      (
        l.dreamActionColorLabel,
        l.dreamActionSize,
        l.dreamPreviewAction,
        prefs.dreamActionColor ?? c.ink2.toARGB32(),
        prefs.dreamActionSize,
        (Color v) => onPrefs(prefs.copyWith(dreamActionColor: v.toARGB32())),
        (double v) => onPrefs(prefs.copyWith(dreamActionSize: v)),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    e.$3,
                    style: contentSerif(c, e.$5, color: Color(e.$4)),
                  ),
                ),
            ],
          ),
        ),
        SettingsRow(
          c: c,
          title: l.dreamDescriptionOpacity,
          subtitle: '${(prefs.dreamDescriptionOpacity * 100).round()}%',
          child: Slider(
            value: prefs.dreamDescriptionOpacity,
            divisions: 20,
            onChanged: (v) =>
                onPrefs(prefs.copyWith(dreamDescriptionOpacity: v)),
          ),
        ),
        for (final e in entries) ...[
          SettingsRow(
            c: c,
            title: e.$1,
            subtitle: '',
            child: TextButton.icon(
              icon: Icon(Icons.circle, color: Color(e.$4)),
              label: Text(
                '#${e.$4.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
              ),
              onPressed: () {
                var selected = Color(e.$4);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => StatefulBuilder(
                    builder: (context, update) => SafeArea(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                color: c.surfaceSoft,
                                child: Text(
                                  e.$3,
                                  style: contentSerif(c, e.$5, color: selected),
                                ),
                              ),
                              const SizedBox(height: 16),
                              FreeColorPicker(
                                c: c,
                                color: selected,
                                onChanged: (value) {
                                  update(() => selected = value);
                                  e.$6(value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SettingsRow(
            c: c,
            title: e.$2,
            subtitle: '${e.$5.round()}',
            child: Slider(
              value: e.$5,
              min: 12,
              max: 28,
              divisions: 16,
              activeColor: c.character,
              onChanged: e.$7,
            ),
          ),
        ],
      ],
    );
  }
}
