import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

/// Both edges work even when the conversation is shorter than the viewport.
/// Observes the list's drag instead of competing with it for the gesture.
class EdgeRefresh extends StatefulWidget {
  const EdgeRefresh({super.key, required this.onRefresh, required this.child});
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<EdgeRefresh> createState() => _EdgeRefreshState();
}

class _EdgeRefreshState extends State<EdgeRefresh> {
  double _pull = 0;
  bool _bottom = true;
  bool _refreshing = false;
  static const _threshold = 72.0;

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _pull = 48;
    });
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _pull = 0;
        });
      }
    }
  }

  bool _onScroll(ScrollNotification event) {
    if (event.depth != 0 ||
        _refreshing ||
        event.metrics.axis != Axis.vertical) {
      return false;
    }
    if (event is OverscrollNotification && event.dragDetails != null) {
      final bottom = event.overscroll > 0;
      setState(() {
        if (_pull > 0 && bottom != _bottom) _pull = 0;
        _bottom = bottom;
        _pull = (_pull + event.overscroll.abs() * .55).clamp(0, 110);
      });
    } else if (event is ScrollUpdateNotification &&
        event.dragDetails != null &&
        _pull > 0 &&
        event.metrics.extentBefore > 0 &&
        event.metrics.extentAfter > 0) {
      setState(() => _pull = 0);
    } else if (event is ScrollEndNotification) {
      if (_pull >= _threshold) {
        unawaited(_refresh());
      } else if (_pull > 0) {
        setState(() => _pull = 0);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ClipRect(
          child: Stack(
            children: [
              Transform.translate(
                offset: Offset(0, _bottom ? -_pull : _pull),
                child: widget.child,
              ),
              if (_pull > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  top: _bottom ? null : 0,
                  bottom: _bottom ? 0 : null,
                  height: _pull,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_refreshing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            _pull >= _threshold
                                ? Icons.refresh
                                : (_bottom
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward),
                            size: 18,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _refreshing
                              ? context.l10n.chatRefreshing
                              : _pull >= _threshold
                              ? context.l10n.chatReleaseRefresh
                              : context.l10n.chatPullRefresh,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
