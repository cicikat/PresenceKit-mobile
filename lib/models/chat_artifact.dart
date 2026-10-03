/// 角色发送的文件元数据，字段与后端 `chat_artifacts.public_payload` 一致，
/// 解析规则对齐桌面端 `normalizeChatArtifacts`。只保存元数据，不含文件内容。
class ChatArtifact {
  const ChatArtifact({
    required this.id,
    required this.filename,
    required this.mime,
    required this.size,
    this.previewable = false,
    this.downloadUrl,
    this.previewUrl,
  });

  static final RegExp idPattern = RegExp(r'^[A-Fa-f0-9]{32}$');
  static const int maxPerTurn = 4;
  static const int maxFilenameChars = 80;

  final String id;
  final String filename;
  final String mime;
  final int size;
  final bool previewable;
  final String? downloadUrl;
  final String? previewUrl;

  /// 无效项返回 null；调用方丢弃，不抛异常。
  static ChatArtifact? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] is String ? raw['id'] as String : '').trim();
    final filename = (raw['filename'] is String ? raw['filename'] as String : '')
        .trim();
    if (!idPattern.hasMatch(id) || filename.isEmpty) return null;
    final size = raw['size'] is num ? (raw['size'] as num).toInt() : 0;
    final mime = raw['mime'] is String && (raw['mime'] as String).trim().isNotEmpty
        ? raw['mime'] as String
        : 'application/octet-stream';
    return ChatArtifact(
      id: id,
      filename: filename.length > maxFilenameChars
          ? filename.substring(0, maxFilenameChars)
          : filename,
      mime: mime,
      size: size < 0 ? 0 : size,
      previewable: raw['previewable'] == true,
      downloadUrl: raw['download_url'] is String
          ? raw['download_url'] as String
          : null,
      previewUrl: raw['preview_url'] is String
          ? raw['preview_url'] as String
          : null,
    );
  }

  static List<ChatArtifact> parseList(Object? raw) {
    if (raw is! List) return const [];
    final items = <ChatArtifact>[];
    for (final entry in raw) {
      final item = tryParse(entry);
      if (item == null) continue;
      items.add(item);
      if (items.length >= maxPerTurn) break;
    }
    return List.unmodifiable(items);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'filename': filename,
    'mime': mime,
    'size': size,
    'previewable': previewable,
    if (downloadUrl != null) 'download_url': downloadUrl,
    if (previewUrl != null) 'preview_url': previewUrl,
  };

  /// 下载与预览端点是固定形状；客户端按 id 自行拼，不信任服务端给的任意路径。
  String get downloadPath => '/chat/artifacts/$id';
  String get previewPath => '/chat/artifacts/$id/preview';

  bool get isTextLike {
    final m = mime.toLowerCase();
    return m.startsWith('text/') ||
        m.startsWith('application/json') ||
        m.startsWith('application/xml');
  }
}
