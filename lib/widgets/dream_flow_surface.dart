import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/app_models.dart';
import '../models/dream_appearance.dart';
import '../models/ui_layout.dart';

YxPalette dreamFlowPalette(DreamLayout layout, bool dark) {
  final base = dark ? YxPalette.dark : YxPalette.light;
  final accent = layout == DreamLayout.theatre
      ? (dark ? const Color(0xffebc780) : const Color(0xff866426))
      : (dark ? const Color(0xffb7bdff) : const Color(0xff5d55a0));
  return base.copyWith(
    surface: dark ? const Color(0xff10111c) : const Color(0xffedf2fc),
    surfaceSoft: dark ? const Color(0xff232538) : const Color(0xfff9faff),
    surfaceEdge: dark ? const Color(0xff555a80) : const Color(0xffbac4df),
    ink1: dark ? const Color(0xfff4f3fa) : const Color(0xff303751),
    ink2: dark ? const Color(0xffd5d7e8) : const Color(0xff4c5672),
    ink3: dark ? const Color(0xffabb2d1) : const Color(0xff667391),
    character: accent,
    characterOn: dark ? const Color(0xfff4f3fa) : const Color(0xff303751),
    characterDeep: dark ? const Color(0xff232538) : const Color(0xffe2e8fa),
    send: accent,
    userBubble: dark ? const Color(0xff292e46) : const Color(0xffdde6fa),
    userBubbleText: dark ? const Color(0xfff4f3fa) : const Color(0xff303751),
  );
}

class DreamFlowSurface extends StatefulWidget {
  const DreamFlowSurface({
    super.key,
    required this.layout,
    required this.settings,
    required this.dark,
    required this.child,
    this.animate = true,
  });
  final DreamLayout layout;
  final DreamFlowSettings settings;
  final bool dark, animate;
  final Widget child;
  @override
  State<DreamFlowSurface> createState() => _DreamFlowSurfaceState();
}

class _DreamFlowSurfaceState extends State<DreamFlowSurface>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static Future<ui.FragmentProgram>? _program;
  final _key = GlobalKey();
  final _clock = ValueNotifier<double>(0);
  late final Ticker _ticker;
  ui.FragmentProgram? _loaded;
  ui.FragmentShader? _shader;
  bool _resumed = true;
  Duration? _last;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick);
    if (isFlowDream(widget.layout)) _load();
  }

  Future<void> _load() async {
    try {
      final program = await (_program ??= ui.FragmentProgram.fromAsset(
        'shaders/dream_flow.frag',
      ));
      if (!mounted) return;
      setState(() {
        _loaded = program;
        _shader = program.fragmentShader();
      });
    } catch (error) {
      _program = null;
      debugPrint('Dream flow shader: $error');
    }
  }

  void _tick(Duration elapsed) {
    final previous = _last;
    _last = elapsed;
    if (previous == null) return;
    _clock.value +=
        (elapsed - previous).inMicroseconds / 1000000 * widget.settings.speed;
  }

  void _motion() {
    final enabled =
        isFlowDream(widget.layout) &&
        widget.animate &&
        _resumed &&
        TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context) &&
        widget.settings.speed > 0;
    if (enabled && !_ticker.isActive) {
      _last = null;
      _ticker.start();
    } else if (!enabled && _ticker.isActive) {
      _ticker.stop();
      _last = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion();
  }

  @override
  void didUpdateWidget(DreamFlowSurface old) {
    super.didUpdateWidget(old);
    if (isFlowDream(widget.layout) &&
        !isFlowDream(old.layout) &&
        _loaded == null) {
      _load();
    }
    _motion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (mounted) _motion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _clock.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FlowScope(
    surface: this,
    child: RepaintBoundary(
      key: _key,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isFlowDream(widget.layout))
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FlowPainter(surface: this, shader: _shader),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    ),
  );
}

class _FlowScope extends InheritedWidget {
  const _FlowScope({required this.surface, required super.child});
  final _DreamFlowSurfaceState surface;
  @override
  bool updateShouldNotify(_FlowScope old) => true;
}

class DreamFlowGlass extends StatefulWidget {
  const DreamFlowGlass({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  @override
  State<DreamFlowGlass> createState() => _DreamFlowGlassState();
}

class _DreamFlowGlassState extends State<DreamFlowGlass> {
  final _key = GlobalKey();
  ui.FragmentShader? _shader;
  ui.FragmentProgram? _program;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = context
        .dependOnInheritedWidgetOfExactType<_FlowScope>()
        ?.surface
        ._loaded;
    if (p != _program) {
      _shader?.dispose();
      _program = p;
      _shader = p?.fragmentShader();
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<_FlowScope>()?.surface;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: CustomPaint(
        key: _key,
        painter: s == null
            ? null
            : _FlowPainter(
                surface: s,
                shader: _shader,
                panelKey: _key,
                radius: widget.radius,
              ),
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.surface,
    required this.shader,
    this.panelKey,
    this.radius = 0,
  }) : super(repaint: surface._clock);
  final _DreamFlowSurfaceState surface;
  final ui.FragmentShader? shader;
  final GlobalKey? panelKey;
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final config = surface.widget, settings = config.settings;
    final root = surface._key.currentContext?.findRenderObject() as RenderBox?;
    final panel = panelKey?.currentContext?.findRenderObject() as RenderBox?;
    final origin = panel != null && root != null
        ? panel.localToGlobal(Offset.zero, ancestor: root)
        : Offset.zero;
    if (shader == null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
        Paint()
          ..shader = LinearGradient(
            colors: panelKey != null
                ? [
                    config.dark
                        ? const Color(0xee202235)
                        : const Color(0xeef9faff),
                    config.dark
                        ? const Color(0xcc262943)
                        : const Color(0xdde9efff),
                  ]
                : settings.colors(config.dark),
          ).createShader(Offset.zero & size),
      );
      return;
    }
    final bounds = panelKey == null ? size : root?.size ?? size;
    final colors = settings.colors(config.dark);
    final values = <double>[
      bounds.width,
      bounds.height,
      surface._clock.value,
      config.layout == DreamLayout.theatre ? 0 : 1,
      settings.scale,
      settings.warp,
      settings.seed,
      config.dark ? 1 : 0,
      for (final color in colors) ...[color.r, color.g, color.b],
      origin.dx,
      origin.dy,
      panelKey == null ? 0 : size.width,
      panelKey == null ? 0 : size.height,
      radius,
      settings.thickness,
      settings.reflection,
    ];
    for (var i = 0; i < values.length; i++) {
      shader!.setFloat(i, values[i]);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_FlowPainter old) => true;
}
