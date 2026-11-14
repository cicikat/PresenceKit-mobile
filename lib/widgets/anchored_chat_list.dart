import 'package:flutter/material.dart';
import '../controllers/chat_scroll_controller.dart';

class AnchoredChatList extends StatefulWidget {
  const AnchoredChatList({
    super.key,
    required this.controller,
    required this.rowIds,
    required this.itemBuilder,
    this.physics,
    this.cacheExtent,
    this.padding,
  });
  final ChatScrollController controller;
  final List<Object> rowIds;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollPhysics? physics;
  final double? cacheExtent;
  final EdgeInsetsGeometry? padding;

  @override
  State<AnchoredChatList> createState() => _AnchoredChatListState();
}

class _AnchoredChatListState extends State<AnchoredChatList> {
  final _center = UniqueKey();
  Object? _pivot;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final rowIds = widget.rowIds;
    final pivot = controller.rebaseBeforeLayout(rowIds);
    _pivot = pivot ?? _pivot;
    if (!rowIds.contains(_pivot)) _pivot = null;
    var split = rowIds.indexOf(_pivot ?? '');
    if (split < 0) split = 0;
    final indices = {
      for (var i = 0; i < rowIds.length; i++) controller.rowKey(rowIds[i]): i,
    };
    Widget row(BuildContext context, int index) => _AnchorRow(
      key: controller.rowKey(rowIds[index]),
      keep: controller.keeps(rowIds[index]),
      child: widget.itemBuilder(context, index),
    );
    final padding = (widget.padding ?? EdgeInsets.zero).resolve(
      Directionality.of(context),
    );
    return NotificationListener<UserScrollNotification>(
      onNotification: (event) {
        if (event.depth == 0) {
          if (event.metrics.extentAfter <= 1) {
            controller.follow();
          } else {
            controller.stopFollowing();
          }
        }
        return false;
      },
      child: CustomScrollView(
        controller: controller,
        physics: widget.physics,
        cacheExtent: widget.cacheExtent,
        center: _center,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              left: padding.left,
              right: padding.right,
              bottom: padding.top,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => row(context, split - 1 - i),
                childCount: split,
                findChildIndexCallback: (key) {
                  final index = indices[key];
                  return index != null && index < split
                      ? split - 1 - index
                      : null;
                },
              ),
            ),
          ),
          SliverPadding(
            key: _center,
            padding: EdgeInsets.only(
              left: padding.left,
              right: padding.right,
              bottom: padding.bottom,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => row(context, split + i),
                childCount: rowIds.length - split,
                findChildIndexCallback: (key) {
                  final index = indices[key];
                  return index != null && index >= split ? index - split : null;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnchorRow extends StatefulWidget {
  const _AnchorRow({super.key, required this.keep, required this.child});
  final bool keep;
  final Widget child;
  @override
  State<_AnchorRow> createState() => _AnchorRowState();
}

class _AnchorRowState extends State<_AnchorRow>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keep;
  @override
  void didUpdateWidget(_AnchorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keep != widget.keep) updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
