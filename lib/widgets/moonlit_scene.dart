import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import 'common_widgets.dart';

YxPalette moonlitPalette(YxPalette base) => base.copyWith(
  surface: const Color(0xFF141D31),
  surfaceSoft: const Color(0xFF243551),
  surfaceDeep: const Color(0xFF19243A),
  surfaceEdge: const Color(0xFF4C6280),
  ink1: const Color(0xFFE9EAF4),
  ink2: const Color(0xFFCFD7E9),
  ink3: const Color(0xFFBCC8DF),
  ink4: const Color(0xFF8F9CB4),
  character: const Color(0xFFC2CCF1),
  characterDeep: const Color(0xFF243551),
  characterSoft: const Color(0xFF314963),
  characterOn: const Color(0xFFE9EAF4),
  send: const Color(0xFF8DABD5),
  userBubble: const Color(0xFF314963),
  userBubbleText: const Color(0xFFE9EAF4),
);

class MoonlitHeader extends StatelessWidget {
  const MoonlitHeader({
    super.key,
    required this.c,
    required this.name,
    required this.onMenu,
    required this.onWake,
  });
  final YxPalette c;
  final String name;
  final VoidCallback onMenu;
  final VoidCallback? onWake;
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 18, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.dreamHeaderTitle(name),
              style: serif(c, 22, color: c.ink1),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _button(
                context,
                Icons.menu_rounded,
                context.l10n.drawerTooltip,
                onMenu,
              ),
              const SizedBox(height: 8),
              _button(
                context,
                Icons.wb_sunny_outlined,
                context.l10n.dreamWakeAction,
                onWake,
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _button(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback? action,
  ) => Material(
    color: c.surfaceSoft.withValues(alpha: .65),
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: action == null ? c.ink4 : c.ink1),
            const SizedBox(width: 5),
            Text(
              label,
              style: serif(c, 12, color: action == null ? c.ink4 : c.ink1),
            ),
          ],
        ),
      ),
    ),
  );
}

class LayoutBackdrop extends StatelessWidget {
  const LayoutBackdrop({
    super.key,
    required this.c,
    required this.moonlit,
    required this.child,
  });
  final YxPalette c;
  final bool moonlit;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (moonlit)
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: MoonlitPainter(c))),
        ),
      child,
    ],
  );
}

class MoonlitPainter extends CustomPainter {
  MoonlitPainter(this.c);
  final YxPalette c;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.surface, c.characterDeep, c.surfaceDeep],
        ).createShader(rect),
    );
    final moon = Offset(size.width * .76, size.height * .24);
    canvas.drawCircle(
      moon,
      62,
      Paint()
        ..shader = RadialGradient(
          colors: [
            c.character.withValues(alpha: .12),
            c.character.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: moon, radius: 62)),
    );
    canvas.drawCircle(
      moon,
      25,
      Paint()..color = c.character.withValues(alpha: .7),
    );
    final stars = Paint()..color = c.character.withValues(alpha: .65);
    for (var i = 0; i < 25; i++) {
      final x = ((i * 73 + 29) % 997) / 997 * size.width;
      final y = ((i * 127 + 43) % 991) / 991 * size.height * .58;
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 1.3 : .7, stars);
    }
    for (var i = 0; i < 3; i++) {
      final y = size.height * (.62 + i * .12);
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(
          size.width * .25,
          y - size.height * .18,
          size.width * .43,
          y + size.height * .12,
          size.width * .64,
          y,
        )
        ..quadraticBezierTo(
          size.width * .87,
          y - size.height * .12,
          size.width,
          y + size.height * .06,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = [
            c.characterSoft,
            c.characterDeep,
            c.surfaceDeep,
          ][i].withValues(alpha: .8),
      );
    }
  }

  @override
  bool shouldRepaint(MoonlitPainter oldDelegate) => c != oldDelegate.c;
}
