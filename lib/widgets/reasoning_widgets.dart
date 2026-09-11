import 'package:flutter/material.dart';
import '../controllers/reasoning_controller.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import 'common_widgets.dart';

class ReasoningPanel extends StatefulWidget {
  const ReasoningPanel({
    super.key,
    required this.c,
    required this.turnId,
    required this.name,
    required this.initiallyExpanded,
    required this.load,
    this.opacity = 0.85,
    this.unavailable = false,
  });
  final double opacity;
  final YxPalette c;
  final String turnId;
  final String name;
  final bool initiallyExpanded;
  final bool unavailable;
  final Future<String> Function(String) load;
  @override
  State<ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<ReasoningPanel> {
  late final controller = ReasoningController(widget.load);
  late bool expanded = widget.initiallyExpanded;
  @override
  void initState() {
    super.initState();
    if (expanded) controller.fetch(widget.turnId);
  }

  @override
  void didUpdateWidget(ReasoningPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (expanded && oldWidget.turnId != widget.turnId) {
      controller.fetch(widget.turnId);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.c.surfaceSoft.withValues(
            alpha: widget.opacity.clamp(0, 1),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() => expanded = !expanded);
                    if (expanded) controller.fetch(widget.turnId);
                  },
                  child: Text(
                    expanded
                        ? context.l10n.reasoningClose
                        : context.l10n.reasoningOpen,
                  ),
                ),
              ),
              if (expanded)
                if (controller.text.isNotEmpty)
                  SelectableText(
                    '${context.l10n.reasoningHeading(widget.name)}\n${controller.text}',
                    textAlign: TextAlign.left,
                    style: serif(widget.c, 14, color: widget.c.ink2),
                  )
                else if (widget.unavailable || controller.failed)
                  TextButton(
                    onPressed: () => controller.fetch(widget.turnId),
                    child: Text(context.l10n.reasoningUnavailable),
                  )
                else
                  Text(
                    context.l10n.loadingStatus,
                    style: serif(widget.c, 13, color: widget.c.ink3),
                  ),
              if (expanded) const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
}
