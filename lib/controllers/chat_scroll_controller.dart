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
  bool _followScheduled = false;
  int _intent = 0;
  static const nearBottom = 80.0;

  GlobalKey rowKey(Object id) => _keys.putIfAbsent(id, () => GlobalKey());
  bool keeps(Object id) => _anchors.any((anchor) => anchor.id == id);

  void stopFollowing() {
    if (following) _intent++;
    following = false;
  }

  void follow() {
    _intent++;
    following = true;
    _anchors.clear();
    _pending = false;
  }

  void reset() {
    follow();
    _keys.clear();
  }

  /// Only a user gesture and its inertia change reading intent. Layout,
  /// keyboard and our own corrections never count as leaving the conversation.
  void handleUserDrag(ScrollMetrics metrics, double delta) {
    if (delta < -0.5) {
      stopFollowing();
    } else if (delta > 0 && metrics.extentAfter <= nearBottom) {
      if (!following) follow();
    }
  }

  /// One coalesced layout follower, also called when lazy sliver estimates or
  /// the viewport change. A later reading gesture invalidates the queued work.
  void followAfterLayout() {
    if (_disposed || !following || _followScheduled) return;
    _followScheduled = true;
    final intent = _intent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      if (_disposed || !following || !hasClients) return;
      if (intent != _intent) {
        followAfterLayout();
        return;
      }
      final view = position;
      if (!view.hasContentDimensions || view.extentAfter <= .5) return;
      jumpTo(view.maxScrollExtent);
      // Lazy rows may revise the extent after the jump.
      followAfterLayout();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
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
