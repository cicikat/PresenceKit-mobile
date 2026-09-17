import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/models/session_scope.dart';

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
}
