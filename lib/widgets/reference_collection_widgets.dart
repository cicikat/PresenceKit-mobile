import 'reference_typography.dart';
import 'reverie_scene.dart';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../models/ui_layout.dart';
import 'reference_art.dart';

class ReferenceCollectionTitle extends StatelessWidget {
  const ReferenceCollectionTitle({
    super.key,
    required this.c,
    required this.title,
    this.action,
  });
  final YxPalette c;
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 25, 20, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: referenceSerif(c, 29).copyWith(height: 1.6, letterSpacing: 1.5),
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class ReferenceDiaryCard extends StatefulWidget {
  const ReferenceDiaryCard({
    super.key,
    required this.c,
    required this.entry,
    required this.layout,
    required this.onTap,
    required this.index,
    required this.loadDetail,
  });
  final YxPalette c;
  final DiaryListItem entry;
  final DailyLayout layout;
  final VoidCallback onTap;
  final int index;
  final Future<DiaryDetail> Function(String date) loadDetail;
  @override
  State<ReferenceDiaryCard> createState() => _ReferenceDiaryCardState();
}

class _ReferenceDiaryCardState extends State<ReferenceDiaryCard> {
  late Future<DiaryDetail> _detail;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _detail = Future.sync(() => widget.loadDetail(widget.entry.date));
  }

  @override
  void didUpdateWidget(ReferenceDiaryCard old) {
    super.didUpdateWidget(old);
    if (old.entry != widget.entry) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final layout = widget.layout;
    final entry = widget.entry;
    final index = widget.index;
    final onTap = widget.onTap;
    final paper = layout == DailyLayout.letter;
    final date = DateTime.tryParse(entry.date);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!paper) Text(entry.date, style: referenceSerif(c, 10, color: c.ink3)),
        const SizedBox(height: 8),
        Text(
          entry.title,
          style: referenceSerif(c, paper ? 17 : 19).copyWith(height: 1.8),
        ),
        FutureBuilder<DiaryDetail>(
          future: _detail,
          builder: (context, snapshot) {
            final body = snapshot.data?.body.trim() ?? '';
            if (body.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                body,
                maxLines: paper ? 3 : 5,
                overflow: TextOverflow.ellipsis,
                style: referenceSerif(c, 12, color: c.ink2).copyWith(height: 2),
              ),
            );
          },
        ),
        if (entry.emotion?.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          Text(entry.emotion!, style: referenceSerif(c, 11, color: c.character)),
        ],
        if (!paper)
          Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.arrow_forward, size: 16, color: c.ink3),
          ),
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        paper ? 8 : 7,
        paper ? 0 : 10,
        paper ? 8 : 7,
        paper ? 0 : 22,
      ),
      child: Transform.rotate(
        angle: paper
            ? 0
            : index.isEven
            ? -.015
            : .022,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: paper ? 0 : 17,
                vertical: paper ? 21 : 17,
              ),
              decoration: BoxDecoration(
                color: paper ? null : c.surfaceSoft,
                border: paper
                    ? Border(bottom: BorderSide(color: c.surfaceEdge))
                    : Border.all(color: c.surfaceEdge),
                boxShadow: paper
                    ? null
                    : [
                        BoxShadow(
                          color: c.ink1.withValues(alpha: .05),
                          offset: const Offset(3, 4),
                        ),
                      ],
              ),
              child: paper
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 56,
                          child: Column(
                            children: [
                              Text(
                                date == null
                                    ? entry.date
                                    : date.day.toString().padLeft(2, '0'),
                                style: referenceSerif(c, 32, color: c.character),
                              ),
                              if (date != null)
                                Text(
                                  '${date.month}/${date.year}',
                                  style: referenceSerif(c, 9, color: c.ink3),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: content),
                      ],
                    )
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        content,
                        Positioned(
                          top: -26,
                          left: 16,
                          child: Transform.rotate(
                            angle: -.04,
                            child: Container(
                              width: 65,
                              height: 18,
                              color: c.character.withValues(alpha: .22),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReferenceGardenBody extends StatelessWidget {
  const ReferenceGardenBody({
    super.key,
    required this.c,
    required this.layout,
    required this.state,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });
  final YxPalette c;
  final DailyLayout layout;
  final GardenState? state;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final paper = layout == DailyLayout.letter;
    final slots = state?.slots ?? const <GardenSlot>[];
    final lead = slots.isEmpty
        ? null
        : slots.reduce((a, b) => a.stageProgress >= b.stageProgress ? a : b);
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: c.character,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ReferenceCollectionTitle(
            c: c,
            title: paper
                ? l.referenceGardenTitle
                : l.referenceWindowGardenTitle,
            action: IconButton(
              onPressed: loading ? null : onRefresh,
              tooltip: l.refreshAction,
              icon: Icon(Icons.refresh, color: c.ink3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(paper ? 0 : 5),
                border: Border.all(color: c.surfaceEdge),
              ),
              clipBehavior: Clip.antiAlias,
              child: paper
                  ? ReferenceLandscape(c: c, garden: true, height: 210)
                  : SizedBox(
                      height: 250,
                      child: CustomPaint(
                        painter: ReveriePainter(
                          c: c,
                          garden: true,
                          progress:
                              lead?.stageProgress.clamp(0, 1).toDouble() ?? 0,
                          live: lead != null,
                        ),
                      ),
                    ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error!, style: referenceSerif(c, 12, color: c.danger)),
            ),
          if (loading)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l.gardenSyncingMessage,
                style: referenceSerif(c, 12, color: c.ink3),
              ),
            ),
          if (state != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  _stat(l.referenceGardenGrowing, slots.length),
                  _stat(l.referenceGardenHarvest, state!.harvestCount),
                  _stat(l.referenceGardenVase, state!.vaseCount),
                ],
              ),
            ),
          if (slots.isEmpty && !loading)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.gardenEmpty, style: referenceSerif(c, 14, color: c.ink3)),
            ),
          for (final slot in slots)
            Container(
              margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: c.surfaceSoft,
                border: Border.all(color: c.surfaceEdge),
                borderRadius: BorderRadius.circular(paper ? 0 : 8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (slot.name.isNotEmpty)
                    Text(slot.name, style: referenceSerif(c, 20)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: slot.stageProgress.clamp(0, 1),
                    color: c.character,
                    backgroundColor: c.surfaceEdge,
                    minHeight: 3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(slot.stageProgress.clamp(0, 1) * 100).round()}%',
                    style: referenceSerif(c, 11, color: c.ink3),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value) => Expanded(
    child: Column(
      children: [
        Text('$value', style: referenceSerif(c, 24, color: c.character)),
        const SizedBox(height: 5),
        Text(label, style: referenceSerif(c, 10, color: c.ink3)),
      ],
    ),
  );
}
