import 'dart:async';

import 'package:flutter/material.dart';
import '../models/app_models.dart';

import '../widgets/common_widgets.dart';
class GardenPage extends StatelessWidget {
  const GardenPage({
    super.key,
    required this.c,
    required this.profileDisplayName,
    required this.onBack,
    required this.gardenState,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final YxPalette c;
  final String profileDisplayName;
  final VoidCallback onBack;
  final GardenState? gardenState;
  final bool loading;
  final String? error;
  final Future<void> Function({bool silent}) onRefresh;

  @override
  Widget build(BuildContext context) {
    final realPlants = gardenState?.slots
        .map((slot) => Plant.fromSlot(slot, c))
        .toList(growable: false);
    final hasLiveData = realPlants != null && realPlants.isNotEmpty;
    final plants = realPlants ?? const <Plant>[];
    final activePlant = hasLiveData
        ? plants.reduce((a, b) => a.percent >= b.percent ? a : b)
        : null;
    return Container(
      color: c.characterDeep,
      child: Column(
        children: [
          PageHeader(
            c: c,
            title: '陪伴花园',
            eyebrow: '$profileDisplayName · 状态花园',
            onBack: onBack,
            darkHeader: true,
            trailing: loading
                ? '同步中'
                : hasLiveData
                ? '已同步'
                : '花园',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading
                      ? '正在读取后端花园状态。'
                      : error != null
                      ? '花园同步失败，稍后可以重新刷新。'
                      : hasLiveData
                      ? '已读取后端花园状态。它在你不看的时候，也在生长。'
                      : '还没有读取到后端花园状态。',
                  style: serif(
                    c,
                    13,
                    color: c.characterOn.withValues(alpha: 0.72),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.characterOn.withValues(alpha: 0.06),
                    border: Border.all(
                      color: c.characterOn.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '他现在 · 主导心境',
                        style: mono(
                          c,
                          10,
                          color: c.characterOn.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          YxTag(
                            c: c,
                            text: activePlant?.mood ?? '等待',
                            variant: 'warm',
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              hasLiveData
                                  ? '${activePlant!.name} · ${activePlant.stage}'
                                  : '等待后端花园数据',
                              style: serif(
                                c,
                                18,
                                color: c.characterOn,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _gardenSummary(
                          live: hasLiveData,
                          state: gardenState,
                          plant: activePlant,
                          error: error,
                        ),
                        style: mono(
                          c,
                          11,
                          color: c.characterOn.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          LiveDot(
                            color: error != null
                                ? c.danger
                                : loading
                                ? c.warn
                                : c.characterOn,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            loading
                                ? '正在同步花园'
                                : error != null
                                ? '同步失败'
                                : hasLiveData
                                ? '后端 · 每 30 秒自动刷新'
                                : '尚未同步',
                            style: mono(
                              c,
                              10,
                              color: c.characterOn.withValues(alpha: 0.7),
                            ),
                          ),
                          const Spacer(),
                          YxIconButton(
                            c: c,
                            icon: Icons.refresh_rounded,
                            onPressed: () =>
                                unawaited(onRefresh(silent: false)),
                            onDark: true,
                            tooltip: '刷新花园',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: plants.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        loading ? '正在同步花园…' : '暂无花园数据',
                        style: serif(
                          c,
                          16,
                          color: c.characterOn.withValues(alpha: 0.62),
                        ),
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.04,
                        ),
                    itemCount: plants.length,
                    itemBuilder: (context, i) =>
                        PlantCard(c: c, plant: plants[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class Plant {
  const Plant(
    this.name,
    this.latin,
    this.mood,
    this.stage,
    this.percent,
    this.accent,
  );

  factory Plant.fromSlot(GardenSlot slot, YxPalette c) {
    return Plant(
      slot.name.isEmpty ? slot.flowerId : slot.name,
      slot.enName.isEmpty ? slot.flowerId : slot.enName,
      slot.slotKey.toUpperCase(),
      slot.stage.toUpperCase(),
      slot.stageProgress.clamp(0, 1).toDouble(),
      _gardenAccent(slot.slotKey, c),
    );
  }

  final String name;
  final String latin;
  final String mood;
  final String stage;
  final double percent;
  final Color accent;
}

Color _gardenAccent(String slotKey, YxPalette c) {
  switch (slotKey) {
    case 'calm':
      return c.warn;
    case 'bright':
      return c.send;
    case 'low':
      return const Color(0xFF5B7BA0);
    case 'yandere':
      return c.danger;
    case 'adrift':
      return const Color(0xFF9A7FC4);
    default:
      return c.ok;
  }
}

String _gardenSummary({
  required bool live,
  required GardenState? state,
  required Plant? plant,
  required String? error,
}) {
  if (error != null) return error;
  if (!live || state == null || plant == null) {
    return '等待后端返回花园槽位。';
  }
  final harvest = state.harvestCount;
  final vase = state.vaseCount;
  final percent = (plant.percent * 100).round();
  return '${plant.mood} 槽位最接近下一阶段 · $percent% · 收获 $harvest · 花瓶 $vase';
}

class PlantCard extends StatelessWidget {
  const PlantCard({super.key, required this.c, required this.plant});

  final YxPalette c;
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.characterOn.withValues(alpha: 0.06),
        border: Border.all(color: c.characterOn.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plant.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: serif(c, 18, color: c.characterOn, weight: FontWeight.w500),
          ),
          const SizedBox(height: 1),
          Text(
            '· ${plant.latin}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mono(c, 10, color: c.characterOn.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: CustomPaint(
              painter: PlantPainter(
                plant.percent,
                plant.accent,
                c.characterOn.withValues(alpha: 0.18),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                plant.mood,
                style: mono(
                  c,
                  9,
                  color: c.characterOn.withValues(alpha: 0.7),
                  weight: FontWeight.w600,
                ),
              ),
              Text(
                ' · ',
                style: mono(c, 9, color: c.characterOn.withValues(alpha: 0.45)),
              ),
              Text(
                plant.stage,
                style: mono(c, 9, color: c.characterOn.withValues(alpha: 0.55)),
              ),
              const Spacer(),
              Text(
                '${(plant.percent * 100).round()}%',
                style: mono(c, 9, color: c.characterOn.withValues(alpha: 0.55)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: plant.percent,
            minHeight: 2,
            color: plant.accent,
            backgroundColor: c.characterOn.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}

class PlantPainter extends CustomPainter {
  PlantPainter(this.percent, this.accent, this.ground);

  final double percent;
  final Color accent;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final groundPaint = Paint()
      ..color = ground
      ..strokeWidth = 1;
    final mid = size.width / 2;
    final base = size.height - 4;
    final top = base - (size.height - 14) * percent;
    canvas.drawLine(Offset(8, base), Offset(size.width - 8, base), groundPaint);
    canvas.drawLine(Offset(mid, base), Offset(mid, top), paint);
    if (percent > 0.4) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(mid - 5, (base + top) / 2),
          width: 10,
          height: 5,
        ),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(mid + 5, (base + top) / 2 - 4),
          width: 10,
          height: 5,
        ),
        paint,
      );
    }
    if (percent > 0.65) {
      final budPaint = Paint()..color = accent;
      canvas.drawCircle(Offset(mid, top), 3, budPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PlantPainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.accent != accent;
  }
}
