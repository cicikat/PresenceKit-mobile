/// Frozen request identity for Reality chat / delivery.
///
/// [generation] is the local ChatSessionCoordinator epoch. Wire freeze uses
/// a server-issued [PresenceSessionGrant] (`X-Presence-Session`) discovered
/// via `GET /auth/whoami` `capabilities.session_scope=v1`.
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

/// Server-advertised session-scope capability from `GET /auth/whoami`.
class SessionScopeCapability {
  const SessionScopeCapability({required this.supported, this.version});

  final bool supported;
  final String? version;

  static const unsupported = SessionScopeCapability(supported: false);

  factory SessionScopeCapability.fromWhoami(Map<String, dynamic> json) {
    final capabilities = json['capabilities'];
    if (capabilities is! Map) return unsupported;
    final raw = capabilities['session_scope']?.toString().trim();
    if (raw == null || raw.isEmpty) return unsupported;
    return SessionScopeCapability(supported: raw == 'v1', version: raw);
  }
}

/// Opaque Reality session issued by `POST /v1/sessions`.
class PresenceSessionGrant {
  const PresenceSessionGrant({
    required this.sessionId,
    required this.charId,
    required this.ownerId,
    required this.domain,
    this.expiresAt,
  });

  final String sessionId;
  final String charId;
  final String ownerId;
  final String domain;
  final DateTime? expiresAt;

  bool get isExpired {
    final expires = expiresAt;
    if (expires == null) return false;
    return !expires.toUtc().isAfter(DateTime.now().toUtc());
  }

  factory PresenceSessionGrant.fromJson(Map<String, dynamic> json) {
    final sessionId = SessionScope.normalize(json['session_id']?.toString());
    final charId = SessionScope.normalize(json['char_id']?.toString());
    if (sessionId == null || charId == null) {
      throw const FormatException('invalid session grant');
    }
    DateTime? expiresAt;
    final rawExpires = json['expires_at'];
    if (rawExpires is num) {
      final seconds = rawExpires.toDouble();
      if (seconds.isFinite && seconds > 0) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000).round(),
          isUtc: true,
        );
      }
    } else if (rawExpires is String && rawExpires.trim().isNotEmpty) {
      expiresAt = DateTime.tryParse(rawExpires.trim());
    }
    return PresenceSessionGrant(
      sessionId: sessionId,
      charId: charId,
      ownerId: SessionScope.normalize(json['owner_id']?.toString()) ?? '',
      domain: SessionScope.normalize(json['domain']?.toString()) ?? 'reality',
      expiresAt: expiresAt,
    );
  }
}
