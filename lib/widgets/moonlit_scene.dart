import 'reference_typography.dart';
import 'reference_art.dart';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';

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

class MoonlitTitle extends StatelessWidget {
  const MoonlitTitle({super.key, required this.c});
  final YxPalette c;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 255),
    padding: const EdgeInsets.only(top: 25),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.referenceMoonlitTitle,
          style: referenceSerif(c, 26).copyWith(height: 1.7, letterSpacing: 1),
        ),
        const SizedBox(height: 14),
        Text(
          context.l10n.referenceMoonlitSubtitle,
          style: referenceSerif(c, 9, color: c.ink3).copyWith(letterSpacing: 2),
        ),
      ],
    ),
  );
}

class MoonlitHeader extends StatelessWidget {
  const MoonlitHeader({
    super.key,
    required this.c,
    required this.name,
    required this.onMenu,
    required this.onWake,
    this.onRoute,
  });
  final YxPalette c;
  final String name;
  final VoidCallback onMenu;
  final VoidCallback? onWake;
  final ValueChanged<AppRoute>? onRoute;
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: c.characterDeep.withValues(alpha: .65),
      border: Border.all(color: c.ink1.withValues(alpha: .1)),
      borderRadius: BorderRadius.circular(25),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(context, Icons.menu_rounded, context.l10n.layoutMenu, onMenu),
        if (onRoute != null) ...[
          const SizedBox(height: 18),
          _button(
            context,
            Icons.menu_book_outlined,
            context.l10n.diaryTitle,
            () => onRoute!(AppRoute.diary),
          ),
          const SizedBox(height: 18),
          _button(
            context,
            Icons.local_florist_outlined,
            context.l10n.gardenShortTitle,
            () => onRoute!(AppRoute.garden),
          ),
        ],
        const SizedBox(height: 18),
        _button(
          context,
          Icons.wb_sunny_outlined,
          context.l10n.dreamWakeAction,
          onWake,
        ),
      ],
    ),
  );
  Widget _button(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback? action,
  ) => Tooltip(
    message: label,
    child: InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Column(
          children: [
            Icon(icon, size: 17, color: action == null ? c.ink4 : c.ink1),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: referenceSerif(c, 8, color: action == null ? c.ink4 : c.ink2),
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
    this.window = false,
    required this.child,
  });
  final YxPalette c;
  final bool window;
  final bool moonlit;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (window)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: ReferenceGridPainter(c)),
          ),
        ),
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
    canvas.save();
    canvas.scale(size.width / 390, size.height / 844);
    const rect = Rect.fromLTWH(0, 0, 390, 844);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF121E36), Color(0xFF344967), Color(0xFF172E3C)],
          stops: [0, .5, .85],
        ).createShader(rect),
    );
    final stars = Paint()..color = c.character.withValues(alpha: .45);
    for (var i = 0; i < 18; i++) {
      final x = ((i * 73 + 29) % 997) / 997 * 390;
      final y = ((i * 127 + 43) % 991) / 991 * 240;
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 1.2 : .6, stars);
    }
    void ridge(Rect bounds, double angle, Color color) {
      canvas.save();
      canvas.translate(bounds.center.dx, bounds.center.dy);
      canvas.rotate(angle);
      final local = Rect.fromCenter(
        center: Offset.zero,
        width: bounds.width,
        height: bounds.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          local,
          topLeft: const Radius.elliptical(150, 100),
          topRight: const Radius.elliptical(250, 100),
        ),
        Paint()..color = color,
      );
      canvas.restore();
    }

    ridge(
      const Rect.fromLTWH(-136, 285, 585, 250),
      -.419,
      const Color(0xFF536579),
    );
    ridge(
      const Rect.fromLTWH(-31, 365, 585, 270),
      .384,
      const Color(0xFF253E50),
    );
    const moon = Offset(261, 280);
    canvas.drawCircle(
      moon,
      70,
      Paint()
        ..shader = RadialGradient(
          colors: [
            c.character.withValues(alpha: .12),
            c.character.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: moon, radius: 70)),
    );
    canvas.drawCircle(
      moon,
      35,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.5, -.5),
          colors: [Color(0xFFEEE9D8), Color(0xFFB8C3CA)],
        ).createShader(Rect.fromCircle(center: moon, radius: 35)),
    );
    const water = Rect.fromLTWH(0, 480, 390, 364);
    canvas.drawRect(
      water,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xC21C394C), Color(0xFF111E32)],
        ).createShader(water),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(MoonlitPainter oldDelegate) => c != oldDelegate.c;
}
