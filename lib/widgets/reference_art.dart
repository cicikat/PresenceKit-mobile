import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/app_models.dart';

class ReferenceLandscape extends StatelessWidget {
  const ReferenceLandscape({
    super.key,
    required this.c,
    this.garden = false,
    this.height = 180,
  });
  final YxPalette c;
  final bool garden;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: ReferenceLandscapePainter(c, garden)),
  );
}

class ReferenceLandscapePainter extends CustomPainter {
  ReferenceLandscapePainter(this.c, this.garden);
  final YxPalette c;
  final bool garden;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 400, size.height / 180);
    final dark = c.surface.computeLuminance() < .2;
    final colors = dark
        ? [
            c.characterDeep,
            c.characterOn,
            c.surfaceEdge,
            c.characterSoft,
            c.surfaceDeep,
          ]
        : [
            const Color(0xFFECE6D4),
            const Color(0xFFFCF8E9),
            const Color(0xFFC2C5A4),
            const Color(0xFF9AA784),
            const Color(0xFF687E65),
          ];
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 400, 180),
      Paint()..color = colors[0],
    );
    canvas.drawCircle(const Offset(285, 51), 25, Paint()..color = colors[1]);
    canvas.drawPath(
      Path()
        ..moveTo(0, 120)
        ..quadraticBezierTo(90, 12, 208, 101)
        ..quadraticBezierTo(326, 190, 420, 81)
        ..lineTo(420, 180)
        ..lineTo(0, 180)
        ..close(),
      Paint()..color = colors[2],
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 108)
        ..quadraticBezierTo(99, 160, 220, 101)
        ..quadraticBezierTo(341, 42, 420, 126)
        ..lineTo(420, 180)
        ..lineTo(0, 180)
        ..close(),
      Paint()..color = colors[3],
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 170)
        ..quadraticBezierTo(180, 100, 400, 165)
        ..lineTo(400, 180)
        ..lineTo(0, 180)
        ..close(),
      Paint()..color = colors[4],
    );
    final stem = Paint()
      ..color = colors[4]
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(66, 158), const Offset(66, 56), stem);
    canvas.drawPath(
      Path()
        ..moveTo(66, 81)
        ..quadraticBezierTo(42, 80, 42, 59)
        ..quadraticBezierTo(65, 60, 66, 81)
        ..moveTo(66, 100)
        ..quadraticBezierTo(91, 99, 91, 78)
        ..quadraticBezierTo(67, 78, 66, 100),
      stem,
    );
    if (garden) {
      final leaf = Paint()..color = colors[4];
      canvas.drawLine(
        const Offset(200, 130),
        const Offset(200, 64),
        stem..strokeWidth = 4,
      );
      canvas.drawPath(
        Path()
          ..moveTo(200, 100)
          ..cubicTo(161, 101, 168, 59, 200, 87)
          ..moveTo(200, 81)
          ..cubicTo(231, 83, 238, 47, 200, 65),
        leaf,
      );
      canvas.drawPath(
        Path()
          ..moveTo(175, 124)
          ..lineTo(225, 124)
          ..lineTo(217, 168)
          ..lineTo(183, 168)
          ..close(),
        Paint()..color = dark ? c.ink3 : const Color(0xFFCB9271),
      );
      canvas.drawLine(
        const Offset(173, 125),
        const Offset(227, 125),
        stem
          ..color = colors[1]
          ..strokeWidth = 5,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ReferenceLandscapePainter old) =>
      c != old.c || garden != old.garden;
}

class ReferenceGridPainter extends CustomPainter {
  ReferenceGridPainter(this.c);
  final YxPalette c;
  @override
  void paint(Canvas canvas, Size size) {
    final dark = c.surface.computeLuminance() < .2;
    if (!dark) {
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(size.width, size.height * .15),
            size.width,
            [const Color(0xFFE6D9F1), const Color(0x00E6D9F1)],
          ),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(0, size.height * .7),
            size.width,
            [const Color(0x33F8D7E5), const Color(0x00F8D7E5)],
          ),
      );
    }
    final paint = Paint()
      ..color = (dark ? Colors.white : c.character).withValues(
        alpha: dark ? .025 : .05,
      )
      ..strokeWidth = .5;
    final step = dark ? 32.0 : 24.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(ReferenceGridPainter old) => c != old.c;
}
