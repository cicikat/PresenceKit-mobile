import 'reference_typography.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import 'common_widgets.dart';

class ReveriePortal extends StatelessWidget {
  const ReveriePortal({super.key, required this.c, required this.onOpen});
  final YxPalette c;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 24),
    child: Material(
      color: c.surfaceSoft,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: c.surfaceEdge),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(Icons.bedtime_outlined, size: 14, color: c.character),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.drawerDreamTitle,
                        style: serif(c, 12),
                      ),
                    ),
                    Icon(Icons.north_east, size: 14, color: c.character),
                  ],
                ),
              ),
              SizedBox(
                height: c.surface.computeLuminance() < .2 ? 174 : 162,
                width: double.infinity,
                child: CustomPaint(painter: ReveriePainter(c: c)),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    context.l10n.dreamEnterAction,
                    style: serif(c, 12, color: c.character),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ReveriePainter extends CustomPainter {
  ReveriePainter({
    required this.c,
    this.garden = false,
    this.progress = 1,
    this.live = true,
  });
  final YxPalette c;
  final bool garden;
  final double progress;
  final bool live;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final scale = math.max(size.width / 360, size.height / 190);
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 190 * scale) / 2,
    );
    canvas.scale(scale);
    final dark = c.surface.computeLuminance() < .2;
    Color tone(int light, int night) => Color(dark ? night : light);
    const rect = Rect.fromLTWH(0, 0, 360, 190);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tone(0xFFC9B5DF, 0xFF080B12),
            tone(0xFFEDD0E4, 0xFF151C29),
            tone(0xFFFAE6ED, 0xFF25303E),
          ],
          stops: const [0, .57, 1],
        ).createShader(rect),
    );
    final cloud = Paint()
      ..color = tone(0xFFFFF5F8, 0xFF708294).withValues(alpha: .8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    for (final oval in [
      const Rect.fromLTWH(-31, 65, 162, 40),
      const Rect.fromLTWH(239, 26, 176, 38),
      const Rect.fromLTWH(211, 111, 192, 46),
      const Rect.fromLTWH(15, 110, 182, 38),
    ]) {
      canvas.drawOval(oval, cloud);
    }
    canvas.drawCircle(
      const Offset(72, 41),
      17,
      Paint()..color = tone(0xFFFFF8F3, 0xFFFF4F9B).withValues(alpha: .65),
    );
    canvas.save();
    canvas.clipPath(
      Path()
        ..moveTo(0, 162)
        ..lineTo(180, 133)
        ..lineTo(360, 162)
        ..lineTo(360, 190)
        ..lineTo(0, 190)
        ..close(),
    );
    canvas.drawRect(
      rect,
      Paint()..color = tone(0xFFF3E3ED, 0xFF26303B).withValues(alpha: .8),
    );
    final tile = Paint()
      ..color = tone(0xFFD3B8D1, 0xFF10141D).withValues(alpha: .8);
    for (var y = 0; y < 18; y++) {
      for (var x = 0; x < 18; x++) {
        if ((x + y).isEven) {
          canvas.drawRect(Rect.fromLTWH(x * 20, y * 11, 20, 11), tile);
        }
      }
    }
    canvas.restore();
    if (!garden) {
      canvas.drawOval(
        const Rect.fromLTWH(178, 109, 80, 14),
        Paint()..color = tone(0xFFC49FBE, 0xFF080B12).withValues(alpha: .4),
      );
      canvas.drawRect(
        const Rect.fromLTWH(187, 36, 47, 76),
        Paint()..color = tone(0xFFBB96BF, 0xFFFF4F9B),
      );
      const door = Rect.fromLTWH(193, 42, 35, 70);
      canvas.drawRect(
        door,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tone(0xFFFFF9F3, 0xFFFFF3D9),
              tone(0xFFF7DEEF, 0xFFFF4F9B),
            ],
          ).createShader(door),
      );
      canvas.drawPath(
        Path()
          ..moveTo(228, 42)
          ..lineTo(242, 32)
          ..lineTo(242, 114)
          ..lineTo(228, 112)
          ..close(),
        Paint()..color = tone(0xFFE7C2D8, 0xFFD91A6F),
      );
      canvas.drawCircle(
        const Offset(236, 77),
        1.4,
        Paint()..color = const Color(0xFFAB77A0),
      );
      canvas.drawPath(
        Path()
          ..moveTo(192, 111)
          ..lineTo(230, 111)
          ..lineTo(230, 121)
          ..lineTo(183, 121)
          ..lineTo(183, 132)
          ..lineTo(174, 132)
          ..lineTo(174, 143)
          ..lineTo(165, 143)
          ..lineTo(165, 154)
          ..lineTo(156, 154)
          ..lineTo(156, 165)
          ..lineTo(117, 165)
          ..lineTo(117, 154)
          ..lineTo(126, 154)
          ..lineTo(126, 143)
          ..lineTo(135, 143)
          ..lineTo(135, 132)
          ..lineTo(144, 132)
          ..lineTo(144, 121)
          ..lineTo(192, 121)
          ..close(),
        Paint()..color = tone(0xFFF8EAF2, 0xFFB9C4CC),
      );
      final edge = Paint()
        ..color = tone(0xFFCEAECB, 0xFF53636E)
        ..strokeWidth = 2;
      for (var i = 0; i < 4; i++) {
        canvas.drawLine(
          Offset(183 - i * 9, 121 + i * 11),
          Offset(230 - i * 9, 121 + i * 11),
          edge,
        );
      }
    } else if (live) {
      final stem = Paint()
        ..color = tone(0xFF9B8AA8, 0xFF739989)
        ..strokeWidth = 4;
      final height = 35 + progress * 45;
      canvas.drawLine(const Offset(186, 143), Offset(186, 143 - height), stem);
      canvas.drawPath(
        Path()
          ..moveTo(185, 110)
          ..quadraticBezierTo(151, 114, 153, 84)
          ..quadraticBezierTo(183, 82, 185, 110)
          ..moveTo(186, 99)
          ..quadraticBezierTo(218, 100, 218, 70)
          ..quadraticBezierTo(188, 70, 186, 99),
        Paint()..color = tone(0xFFB1A3B9, 0xFF719989),
      );
      if (progress > .4) {
        final top = 143 - height - 18;
        final petal = Paint()..color = tone(0xFFD187AE, 0xFFFF4F9B);
        canvas.drawRect(Rect.fromLTWH(174, top, 24, 48), petal);
        canvas.drawRect(Rect.fromLTWH(162, top + 12, 48, 24), petal);
        canvas.drawRect(
          Rect.fromLTWH(177, top + 15, 18, 18),
          Paint()..color = const Color(0xFFFFF0D5),
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(161, 140)
          ..lineTo(211, 140)
          ..lineTo(202, 175)
          ..lineTo(170, 175)
          ..close(),
        Paint()..color = tone(0xFFD3A6C1, 0xFF283641),
      );
      canvas.drawLine(
        const Offset(157, 140),
        const Offset(215, 140),
        Paint()
          ..color = tone(0xFFF9EEF5, 0xFFB7C9C2)
          ..strokeWidth = 5,
      );
    }
    final star = Paint()..color = tone(0xFFFFF5FB, 0xFFC2F3DF);
    for (final point in [const Offset(304, 71), const Offset(116, 29)]) {
      canvas.drawRect(
        Rect.fromCenter(center: point, width: 4, height: 18),
        star,
      );
      canvas.drawRect(
        Rect.fromCenter(center: point, width: 18, height: 4),
        star,
      );
    }
    for (final point in [const Offset(59, 112), const Offset(283, 110)]) {
      canvas.drawRect(Rect.fromLTWH(point.dx, point.dy, 3, 3), star);
    }
    final accent = Paint()..color = tone(0xFFB581B1, 0xFFFF4F9B);
    canvas.drawRect(const Rect.fromLTWH(270, 28, 3, 3), accent);
    canvas.drawRect(const Rect.fromLTWH(91, 85, 3, 3), accent);
    canvas.drawRect(const Rect.fromLTWH(42, 135, 4, 12), accent);
    canvas.drawRect(const Rect.fromLTWH(38, 139, 12, 4), accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ReveriePainter old) =>
      c != old.c ||
      garden != old.garden ||
      progress != old.progress ||
      live != old.live;
}

class MessageWindow extends StatelessWidget {
  const MessageWindow({
    super.key,
    required this.enabled,
    required this.c,
    required this.child,
    this.label,
    this.time,
  });
  final bool enabled;
  final YxPalette c;
  final Widget child;
  final String? label;
  final String? time;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: enabled ? Clip.antiAlias : Clip.none,
    decoration: enabled
        ? BoxDecoration(
            color: c.surfaceSoft,
            border: Border.all(color: c.surfaceEdge),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: c.ink1.withValues(alpha: .08),
                offset: const Offset(3, 3),
              ),
            ],
          )
        : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (enabled)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: c.character.withValues(alpha: .1),
              border: Border(bottom: BorderSide(color: c.surfaceEdge)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: referenceUiText(c, 8, color: c.ink2, spacing: .7),
                  ),
                ),
                if (time != null)
                  Text(time!, style: referenceUiText(c, 8, color: c.ink3)),
              ],
            ),
          ),
        Padding(padding: EdgeInsets.zero, child: child),
      ],
    ),
  );
}
