import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';
import 'package:presencekit_mobile/models/session_scope.dart';
import 'package:presencekit_mobile/services/backend_client.dart';

void main() {
  test('normalize trims empty values to null', () {
    expect(SessionScope.normalize('  a  '), 'a');
    expect(SessionScope.normalize(''), isNull);
    expect(SessionScope.normalize('   '), isNull);
    expect(SessionScope.normalize(null), isNull);
  });

  test('matchesLive requires generation and identity', () {
    const scope = SessionScope(
      origin: 'http://127.0.0.1:8080',
      owner: 'owner',
      charId: 'char-b',
      generation: 3,
    );
    expect(
      scope.matchesLive(
        generation: 3,
        origin: 'http://127.0.0.1:8080',
        owner: 'owner',
        charId: 'char-b',
      ),
      isTrue,
    );
    expect(
      scope.matchesLive(
        generation: 4,
        origin: 'http://127.0.0.1:8080',
        owner: 'owner',
        charId: 'char-b',
      ),
      isFalse,
    );
    expect(
      scope.matchesLive(
        generation: 3,
        origin: 'http://127.0.0.1:8080',
        owner: 'owner',
        charId: 'char-a',
      ),
      isFalse,
    );
  });

  test('acceptsMessageChar keeps unscoped and matching envelopes', () {
    const scoped = SessionScope(charId: 'char-b', generation: 1);
    expect(scoped.acceptsMessageChar(null), isTrue);
    expect(scoped.acceptsMessageChar('char-b'), isTrue);
    expect(scoped.acceptsMessageChar('char-a'), isFalse);

    const unscoped = SessionScope(generation: 1);
    expect(unscoped.acceptsMessageChar('char-a'), isTrue);
  });

  test('mediaCachePrefix includes origin owner char', () {
    const scope = SessionScope(
      origin: 'http://x',
      owner: 'o',
      charId: 'c',
      generation: 1,
    );
    expect(scope.mediaCachePrefix, 'http://x|o|c');
  });

  test('whoami without v1 is unsupported', () {
    expect(
      SessionScopeCapability.fromWhoami(const {
        'label': 'mobile',
        'scopes': ['chat'],
      }).supported,
      isFalse,
    );
    expect(
      SessionScopeCapability.fromWhoami(const {
        'capabilities': {'session_scope': 'v1'},
      }).supported,
      isTrue,
    );
    expect(
      SessionScopeCapability.fromWhoami(const {
        'capabilities': {'session_scope': 'v0'},
      }).supported,
      isFalse,
    );
  });

  test('session grant requires opaque session_id and frozen char_id', () {
    final grant = PresenceSessionGrant.fromJson(const {
      'session_id': 'pss_fixture',
      'char_id': 'char-b',
      'owner_id': 'owner',
      'domain': 'reality',
      'expires_at': 1770000000,
    });
    expect(grant.sessionId, 'pss_fixture');
    expect(grant.charId, 'char-b');
    expect(grant.expiresAt!.isUtc, isTrue);
    expect(grant.isExpired, isTrue);
    expect(
      PresenceSessionGrant(
        sessionId: 'pss_live',
        charId: 'char-b',
        ownerId: 'owner',
        domain: 'reality',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ).isExpired,
      isFalse,
    );
    expect(
      () => PresenceSessionGrant.fromJson(const {'char_id': 'char-b'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('session error codes survive 403 mapping', () {
    expect(
      BackendClient.debugExtractError(
        '{"detail": "character_revoked"}',
        403,
      ),
      'character_revoked',
    );
    expect(
      BackendClient.debugExtractError(
        '{"detail": "session_not_found"}',
        404,
      ),
      'session_not_found',
    );
    expect(
      BackendClient.debugExtractError('{"detail": "in_flight"}', 202),
      'in_flight',
    );
  });

  test('session error codes localize without leaking protocol ids', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(
      localizeSessionScopeError(l10n, 'session_scope_unsupported'),
      l10n.sessionScopeUnsupported,
    );
    expect(
      localizeSessionScopeError(l10n, 'character_revoked'),
      l10n.sessionCharacterRevoked,
    );
    expect(localizeSessionScopeError(l10n, 'offline'), 'offline');
  });
}
