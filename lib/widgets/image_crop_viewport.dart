import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

/// Crop coordinates are always source-image coordinates, never a screenshot
/// of a decorated widget or a letterboxed Image's layout bounds.
class ImageCropViewport extends StatefulWidget {
  const ImageCropViewport({
    super.key,
    required this.bytes,
    required this.aspectRatio,
  });
  final Uint8List bytes;
  final double aspectRatio;

  @override
  State<ImageCropViewport> createState() => ImageCropViewportState();
}

class ImageCropViewportState extends State<ImageCropViewport> {
  ui.Image? _image;
  bool _failed = false;
  Size _viewport = Size.zero;
  double _zoom = 1;
  double _gestureZoom = 1;
  Offset _offset = Offset.zero;
  Offset _anchor = Offset.zero;

  double get _baseScale => math.max(
    _viewport.width / _image!.width,
    _viewport.height / _image!.height,
  );
  double get _scale => _baseScale * _zoom;

  Rect get sourceRect => Rect.fromLTWH(
    -_offset.dx / _scale,
    -_offset.dy / _scale,
    _viewport.width / _scale,
    _viewport.height / _scale,
  );

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      late final ui.FrameInfo frame;
      try {
        frame = await codec.getNextFrame();
      } finally {
        codec.dispose();
      }
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _clamp() {
    _offset = Offset(
      _offset.dx.clamp(
        math.min(0, _viewport.width - _image!.width * _scale),
        0,
      ),
      _offset.dy.clamp(
        math.min(0, _viewport.height - _image!.height * _scale),
        0,
      ),
    );
  }

  void reset() {
    if (_image == null) return;
    setState(() {
      _zoom = 1;
      _offset = Offset(
        (_viewport.width - _image!.width * _scale) / 2,
        (_viewport.height - _image!.height * _scale) / 2,
      );
      _clamp();
    });
  }

  void _setZoom(double value) {
    final center = _viewport.center(Offset.zero);
    final anchor = (center - _offset) / _scale;
    setState(() {
      _zoom = value.clamp(1, 5);
      _offset = center - anchor * _scale;
      _clamp();
    });
  }

  Future<Uint8List?> crop({int maxDimension = 2048}) async {
    if (_image == null || _viewport.isEmpty) return null;
    final source = sourceRect.intersect(
      Rect.fromLTWH(0, 0, _image!.width.toDouble(), _image!.height.toDouble()),
    );
    final ratio = math.min(
      1.0,
      maxDimension / math.max(source.width, source.height),
    );
    final width = math.max(1, (source.width * ratio).round());
    final height = math.max(1, (source.height * ratio).round());
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      _image!,
      source,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final output = await picture.toImage(width, height);
    picture.dispose();
    try {
      final data = await output.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      output.dispose();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            if (_viewport != size && _image != null) {
              _viewport = size;
              _zoom = 1;
              _offset = Offset(
                (size.width - _image!.width * _scale) / 2,
                (size.height - _image!.height * _scale) / 2,
              );
              _clamp();
            }
            if (_failed) {
              return Center(child: Text(context.l10n.imageDecodeFailed));
            }
            if (_image == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return GestureDetector(
              key: const ValueKey('crop-gesture'),
              behavior: HitTestBehavior.opaque,
              onScaleStart: (details) {
                _gestureZoom = _zoom;
                _anchor = (details.localFocalPoint - _offset) / _scale;
              },
              onScaleUpdate: (details) => setState(() {
                _zoom = (_gestureZoom * details.scale).clamp(1, 5);
                _offset = details.localFocalPoint - _anchor * _scale;
                _clamp();
              }),
              child: ClipRect(
                child: CustomPaint(
                  painter: _CropPainter(_image!, _offset, _scale),
                  foregroundPainter: _CropBorder(
                    Theme.of(context).colorScheme.onSurface,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            );
          },
        ),
      ),
      Row(
        children: [
          const Icon(Icons.zoom_out, size: 18),
          Expanded(
            child: Slider(
              value: _zoom,
              min: 1,
              max: 5,
              label: '${_zoom.toStringAsFixed(1)}×',
              onChanged: _image == null ? null : _setZoom,
            ),
          ),
          const Icon(Icons.zoom_in, size: 18),
        ],
      ),
    ],
  );
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.offset, this.scale);
  final ui.Image image;
  final Offset offset;
  final double scale;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    offset & Size(image.width * scale, image.height * scale),
    Paint()..filterQuality = FilterQuality.high,
  );
  @override
  bool shouldRepaint(_CropPainter old) =>
      image != old.image || offset != old.offset || scale != old.scale;
}

class _CropBorder extends CustomPainter {
  _CropBorder(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
    (Offset.zero & size).deflate(1),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  @override
  bool shouldRepaint(_CropBorder old) => old.color != color;
}
