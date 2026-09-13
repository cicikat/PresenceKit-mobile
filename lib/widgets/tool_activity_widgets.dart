import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../models/tool_activity.dart';
import 'common_widgets.dart';

class ToolActivityRow extends StatelessWidget {
  const ToolActivityRow({
    super.key,
    required this.c,
    required this.activity,
    this.connectBefore = false,
    this.connectAfter = false,
  });
  final YxPalette c;
  final ToolActivity activity;
  final bool connectBefore;
  final bool connectAfter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (activity.status) {
      'success' => l10n.toolActivitySuccess,
      'error' => l10n.toolActivityError,
      'pending_confirmation' => l10n.toolActivityPending,
      'running' => l10n.toolActivityRunning,
      _ => l10n.toolActivityUnknown,
    };
    final color = switch (activity.status) {
      'success' => const Color(0xFF4C9B70),
      'error' => const Color(0xFFD36B6B),
      _ => c.ink3,
    };
    return Center(
      child: SizedBox(
        width: 220,
        height: 22,
        child: Semantics(
          label: '${activity.name}: $label',
          child: Tooltip(
            message: label,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    activity.name,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono(c, 9.5, color: c.ink2),
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 8,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: 1,
                          color: connectBefore
                              ? c.ink3.withValues(alpha: .4)
                              : null,
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: 1,
                          color: connectAfter
                              ? c.ink3.withValues(alpha: .4)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 35),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
