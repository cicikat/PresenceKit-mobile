import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Keeps actual visible rows fixed; appended content never contributes to the
/// correction. A few visible neighbours provide a fallback after reconciliation.
class ChatScrollController extends ScrollController {
  final _keys = <Object, GlobalKey>{};
  final _anchors = <({Object id, double y})>[];
  bool following = true;
  bool _pending = false;
  bool _disposed = false;

  GlobalKey rowKey(Object id) => _keys.putIfAbsent(id, () => GlobalKey());
  bool keeps(Object id) => _anchors.any((anchor) => anchor.id == id);

  void stopFollowing() {
    following = false;
  }

  void follow() {
    following = true;
    _anchors.clear();
    _pending = false;
  }

  void reset() {
    follow();
    _keys.clear();
  }

  void preserveBeforeLayout() {
    if (_disposed || following || !hasClients || _pending) return;
    _keys.removeWhere((_, key) => key.currentContext == null);
    _anchors.clear();
    for (final entry in _keys.entries) {
      if (entry.key is! int) continue; // Only real message rows are anchors.
      final box = entry.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport is! RenderBox) continue;
      final y = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      if (y < position.viewportDimension && y + box.size.height > 0) {
        _anchors.add((id: entry.key, y: y));
      }
    }
    _anchors.sort((a, b) => a.y.compareTo(b.y));
    if (_anchors.isEmpty) return;
    _pending = true;
  }

  Object? rebaseBeforeLayout(List<Object> ids) {
    if (!_pending || following || !hasClients) return null;
    _pending = false;
    for (final anchor in _anchors) {
      if (!ids.contains(anchor.id)) continue;
      // A centered sliver grows in both directions from the chosen bubble.
      // Rebasing its origin preserves the measured viewport coordinate exactly,
      // without estimating the heights of newly inserted off-screen rows.
      position.correctPixels(-anchor.y);
      return anchor.id;
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
