/// Frozen request identity for Reality chat / delivery.
///
/// [generation] is the local ChatSessionCoordinator epoch. Backend wire
/// fields for authorized frozen char_id / request_id still come from backend
/// work order B/C; this type only freezes what the phone already knows.
class SessionScope {
  const SessionScope({
    this.origin,
    this.owner,
    this.charId,
    required this.generation,
  });

  final String? origin;
  final String? owner;
  final String? charId;
  final int generation;

  static String? normalize(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  static String scopeKey({String? origin, String? owner}) {
    final o = normalize(origin) ?? '';
    final u = normalize(owner) ?? '';
    return '$o|$u';
  }

  String get mediaCachePrefix =>
      '${normalize(origin) ?? ''}|${normalize(owner) ?? ''}|${normalize(charId) ?? ''}';

  bool matchesLive({
    required int generation,
    String? origin,
    String? owner,
    String? charId,
  }) {
    if (this.generation != generation) return false;
    return normalize(this.origin) == normalize(origin) &&
        normalize(this.owner) == normalize(owner) &&
        normalize(this.charId) == normalize(charId);
  }

  /// True when [messageCharId] belongs to this session, or either side is
  /// unscoped (legacy envelopes without char_id stay visible).
  bool acceptsMessageChar(String? messageCharId) {
    final expected = normalize(charId);
    final actual = normalize(messageCharId);
    if (expected == null || actual == null) return true;
    return expected == actual;
  }
}
