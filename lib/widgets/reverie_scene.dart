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
                height: 150,
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
  ReveriePainter({required this.c});
  final YxPalette c;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final dark = c.surface.computeLuminance() < .2;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.character.withValues(alpha: dark ? .1 : .25),
            c.surfaceSoft,
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * .19, size.height * .24),
      16,
      Paint()..color = c.character.withValues(alpha: .35),
    );
    final floor = Paint();
    const unit = 18.0;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < size.width / unit; col++) {
        floor.color = ((col + row).isEven ? c.character : c.surfaceEdge)
            .withValues(alpha: .22);
        canvas.drawRect(
          Rect.fromLTWH(col * unit, size.height - 36 + row * 12, unit, 12),
          floor,
        );
      }
    }
    final x = size.width * .62, y = size.height * .17;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x + 15, y + 92), width: 90, height: 12),
      Paint()..color = c.ink1.withValues(alpha: .08),
    );
    canvas.drawRect(
      Rect.fromLTWH(x - 4, y - 4, 48, 86),
      Paint()..color = c.character.withValues(alpha: .65),
    );
    final door = Rect.fromLTWH(x, y, 36, 78);
    canvas.drawRect(
      door,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            dark ? const Color(0xFFFFF2DB) : Colors.white,
            c.character.withValues(alpha: .4),
          ],
        ).createShader(door),
    );
    final step = Paint()..color = c.ink3.withValues(alpha: .35);
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(x - 8 - i * 12, y + 80 + i * 8, 52 - i * 3, 6),
        step,
      );
    }
    final star = Paint()..color = dark ? const Color(0xFFBDE6D7) : c.character;
    for (final p in [
      Offset(size.width * .32, 20),
      Offset(size.width * .84, 64),
      Offset(size.width * .12, 115),
    ]) {
      canvas.drawRect(Rect.fromCenter(center: p, width: 3, height: 13), star);
      canvas.drawRect(Rect.fromCenter(center: p, width: 13, height: 3), star);
    }
  }

  @override
  bool shouldRepaint(ReveriePainter oldDelegate) => c != oldDelegate.c;
}

class MessageWindow extends StatelessWidget {
  const MessageWindow({
    super.key,
    required this.enabled,
    required this.c,
    required this.child,
  });
  final bool enabled;
  final YxPalette c;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: enabled ? const EdgeInsets.all(12) : EdgeInsets.zero,
    decoration: enabled
        ? BoxDecoration(
            color: c.surfaceSoft,
            border: Border.all(color: c.surfaceEdge),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: c.ink1.withValues(alpha: .05),
                offset: const Offset(3, 4),
              ),
            ],
          )
        : null,
    child: child,
  );
}
