import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/chat_artifact.dart';
import '../services/backend_client.dart' show BackendException;
import '../services/chat_artifact_saver.dart';
import 'common_widgets.dart';

typedef ArtifactFetcher =
    Future<Uint8List> Function(
      ChatArtifact artifact, {
      void Function(int received, int? total)? onProgress,
    });

String formatArtifactSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

IconData artifactIcon(ChatArtifact a) {
  final name = a.filename.toLowerCase();
  final mime = a.mime.toLowerCase();
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime == 'application/pdf' || name.endsWith('.pdf')) {
    return Icons.picture_as_pdf_outlined;
  }
  if (name.endsWith('.csv')) return Icons.table_chart_outlined;
  const code = ['.json', '.py', '.js', '.css', '.html', '.htm', '.xml', '.yaml', '.yml', '.toml'];
  if (code.any(name.endsWith)) return Icons.code;
  if (name.endsWith('.md') || name.endsWith('.txt')) {
    return Icons.description_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

/// 角色发送的文件卡片：文件名、大小、类型图标；预览与下载按钮。
class ArtifactMessage extends StatelessWidget {
  const ArtifactMessage({
    super.key,
    required this.c,
    required this.artifacts,
    required this.fetch,
    this.bubbleOpacity = 1,
    this.saver = const ChatArtifactSaver(),
  });

  final YxPalette c;
  final List<ChatArtifact> artifacts;
  final ArtifactFetcher fetch;
  final double bubbleOpacity;
  final ChatArtifactSaver saver;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 36, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final a in artifacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ArtifactCard(
                key: ValueKey('artifact-${a.id}'),
                c: c,
                artifact: a,
                fetch: fetch,
                bubbleOpacity: bubbleOpacity,
                saver: saver,
              ),
            ),
        ],
      ),
    );
  }
}

class ArtifactCard extends StatefulWidget {
  const ArtifactCard({
    super.key,
    required this.c,
    required this.artifact,
    required this.fetch,
    this.bubbleOpacity = 1,
    this.saver = const ChatArtifactSaver(),
  });

  final YxPalette c;
  final ChatArtifact artifact;
  final ArtifactFetcher fetch;
  final double bubbleOpacity;
  final ChatArtifactSaver saver;

  @override
  State<ArtifactCard> createState() => _ArtifactCardState();
}

class _ArtifactCardState extends State<ArtifactCard> {
  bool _busy = false;
  double? _progress;
  String? _notice;
  bool _noticeIsError = false;

  void _setNotice(String text, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _notice = text;
      _noticeIsError = error;
    });
  }

  Future<Uint8List?> _load() async {
    setState(() {
      _busy = true;
      _progress = null;
      _notice = null;
    });
    try {
      return await widget.fetch(
        widget.artifact,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _progress = total != null && total > 0 ? received / total : null;
          });
        },
      );
    } on BackendException catch (e) {
      _setNotice(e.message, error: true);
    } catch (_) {
      _setNotice('获取文件失败，请稍后重试', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return null;
  }

  Future<void> _preview() async {
    final bytes = await _load();
    if (bytes == null || !mounted) return;
    if (!widget.artifact.isTextLike) {
      _setNotice('此类型暂不支持应用内预览，请下载后查看', error: true);
      return;
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.c.surface,
        title: Text(
          widget.artifact.filename,
          style: mono(widget.c, 12, color: widget.c.ink1),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              key: const ValueKey('artifact-preview-text'),
              style: mono(widget.c, 11.5, color: widget.c.ink1),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _download() async {
    final a = widget.artifact;
    if (!a.isTextLike) {
      _setNotice('此类型暂不支持保存到手机', error: true);
      return;
    }
    final bytes = await _load();
    if (bytes == null || !mounted) return;
    if (!widget.saver.available) {
      _setNotice('当前平台不支持保存文件', error: true);
      return;
    }
    final saved = await widget.saver.saveText(
      filename: a.filename,
      mime: a.mime,
      text: utf8.decode(bytes, allowMalformed: true),
    );
    _setNotice(saved ? '已保存：${a.filename}' : '未保存（已取消或被系统拒绝）', error: !saved);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final a = widget.artifact;
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: c.surfaceSoft.withValues(alpha: widget.bubbleOpacity),
        border: Border.all(color: c.surfaceEdge),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(artifactIcon(a), size: 22, color: c.ink2),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.filename,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: mono(c, 12, color: c.ink1),
                    ),
                    Text(
                      '${formatArtifactSize(a.size)}  ·  ${a.mime.split(';').first}',
                      style: mono(c, 9.5, color: c.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                key: const ValueKey('artifact-progress'),
                value: _progress,
                minHeight: 2,
              ),
            ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _notice!,
                key: const ValueKey('artifact-notice'),
                style: mono(c, 10, color: _noticeIsError ? c.danger : c.ink2),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (a.previewable)
                TextButton(
                  key: const ValueKey('artifact-preview'),
                  onPressed: _busy ? null : _preview,
                  child: const Text('预览'),
                ),
              TextButton(
                key: const ValueKey('artifact-download'),
                onPressed: _busy ? null : _download,
                child: const Text('下载'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
