import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';

class PresenceSnapshot {
  const PresenceSnapshot({
    required this.status,
    required this.subline,
    required this.mood,
    required this.activity,
    required this.timeband,
    this.dotColor,
  });

  factory PresenceSnapshot.current(AppLocalizations l10n) {
    return PresenceSnapshot(
      status: l10n.presenceOnline,
      subline: l10n.presenceMobileOnline,
      mood: l10n.presenceReady,
      activity: l10n.presenceChatting,
      timeband: l10n.presenceNow,
    );
  }

  final String status;
  final String subline;
  final String mood;
  final String activity;
  final String timeband;
  final Color? dotColor;
}

TextStyle serif(YxPalette c, double size, {Color? color, FontWeight? weight}) {
  return TextStyle(
    fontFamily: 'serif',
    fontSize: size,
    height: 1.35,
    color: color ?? c.ink1,
    fontWeight: weight,
    letterSpacing: 0,
  );
}

TextStyle mono(YxPalette c, double size, {Color? color, FontWeight? weight}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    height: 1.3,
    color: color ?? c.ink2,
    fontWeight: weight,
    letterSpacing: 0,
  );
}

class NavPill extends StatelessWidget {
  const NavPill({super.key, required this.c});

  final YxPalette c;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Center(
        child: Container(
          width: 108,
          height: 4,
          decoration: BoxDecoration(
            color: c.ink1.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class LiveDot extends StatelessWidget {
  const LiveDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Pulse(
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.55,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

class YxTag extends StatelessWidget {
  const YxTag({
    super.key,
    required this.c,
    required this.text,
    this.variant = 'plain',
  });

  final YxPalette c;
  final String text;
  final String variant;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color fg = c.ink2;
    Color border = c.ink4;
    if (variant == 'solid') {
      bg = c.ink1;
      fg = c.surface;
      border = c.ink1;
    } else if (variant == 'warm') {
      bg = c.warn.withValues(alpha: 0.16);
      fg = c.warn;
      border = bg;
    } else if (variant == 'character') {
      bg = c.character;
      fg = c.characterOn;
      border = c.characterDeep;
    } else if (variant == 'danger') {
      bg = c.danger;
      fg = const Color(0xFFF1E9D6);
      border = c.danger;
    } else if (variant == 'warn') {
      fg = c.warn;
      border = c.warn;
    } else if (variant == 'ok') {
      fg = c.ok;
      border = c.ok;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(1),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: mono(c, 10, color: fg, weight: FontWeight.w600),
      ),
    );
  }
}

class YxAvatar extends StatelessWidget {
  const YxAvatar({
    super.key,
    required this.c,
    this.text = '叶',
    this.imageBytes,
    this.size = 28,
    this.onDark = false,
  });

  final YxPalette c;
  final String text;
  final Uint8List? imageBytes;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? c.characterOn : c.character;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onDark ? Colors.transparent : c.characterSoft,
        border: Border.all(color: fg),
      ),
      child: imageBytes == null
          ? Text(
              text,
              style: serif(
                c,
                size * 0.5,
                color: fg,
              ).copyWith(fontStyle: FontStyle.italic),
            )
          : ClipOval(
              child: Image.memory(
                imageBytes!,
                width: size,
                height: size,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                cacheHeight: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
              ),
            ),
    );
  }
}

class YxIconButton extends StatelessWidget {
  const YxIconButton({
    super.key,
    required this.c,
    required this.icon,
    required this.onPressed,
    this.onDark = false,
    this.tooltip,
    this.size = 32,
  });

  final YxPalette c;
  final IconData icon;
  final VoidCallback onPressed;
  final bool onDark;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? c.characterOn : c.ink1;
    return Tooltip(
      message: tooltip ?? '',
      child: SizedBox(
        width: size,
        height: size,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: size * 0.56,
          color: fg,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: fg.withValues(alpha: 0.38)),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.c, required this.text});

  final YxPalette c;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: mono(c, 10, color: c.ink3)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: c.ink4)),
      ],
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.c,
    required this.title,
    required this.eyebrow,
    required this.onBack,
    required this.trailing,
    this.darkHeader = false,
  });

  final YxPalette c;
  final String title;
  final String eyebrow;
  final VoidCallback onBack;
  final String trailing;
  final bool darkHeader;

  @override
  Widget build(BuildContext context) {
    final bg = darkHeader ? c.characterDeep : c.characterDeep;
    final fg = c.characterOn;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: bg,
      child: Row(
        children: [
          YxIconButton(
            c: c,
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
            onDark: true,
            tooltip: context.l10n.backTooltip,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: mono(c, 10, color: fg.withValues(alpha: 0.55)),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: serif(c, 19, color: fg, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
          YxTag(c: c, text: trailing),
        ],
      ),
    );
  }
}
