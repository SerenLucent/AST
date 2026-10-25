import 'dart:async';
import 'dart:convert';

import 'package:ast_team_web/src/services/ast_home_contribution_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('reads only the public home JSON with GET and no credentials', () async {
    final requests = <http.Request>[];
    final repository = AstHomeContributionRepository(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'schemaVersion': 1,
              'contributions': {'한글계정': 100, 'tester': 30},
              // Unrelated state must never be used as a wallet balance.
              'balance': 999999,
              'items': [],
              'receipts': [],
            }),
          ),
          200,
        );
      }),
    );
    addTearDown(repository.close);

    final rows = await repository.fetch();
    expect(rows.map((r) => r.key), ['한글계정', 'tester']);
    expect(rows.map((r) => r.value), [100, 30]);
    expect(requests, hasLength(1));
    final request = requests.single;
    expect(request.method, 'GET');
    expect(request.url.scheme, 'https');
    expect(request.url.host, 'raw.githubusercontent.com');
    expect(
      request.url.path,
      '/SerenLucent/AST/main/remote-data/games/ast-home/state.json',
    );
    expect(request.url.queryParameters.keys, ['v']);
    expect(request.url.queryParameters['v'], isNotEmpty);
    expect(request.headers.keys.map((key) => key.toLowerCase()), ['accept']);
    expect(request.headers.containsKey('authorization'), isFalse);
    expect(request.body, isEmpty);
  });

  test(
    'each fetch reads a fresh snapshot instead of reusing previous totals',
    () async {
      var gets = 0;
      final repository = AstHomeContributionRepository(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'schemaVersion': 1,
              'contributions': {'tester': 30 * ++gets},
            }),
            200,
          ),
        ),
      );
      addTearDown(repository.close);
      expect((await repository.fetch()).single.value, 30);
      expect((await repository.fetch()).single.value, 60);
      expect(gets, 2);
    },
  );

  test('sorts descending by contribution with stable login ID ties', () {
    final repository = AstHomeContributionRepository();
    addTearDown(repository.close);
    final rows = repository.decode(
      jsonEncode({
        'schemaVersion': 1,
        'contributions': {'c': 30, 'b': 100, 'a': 100, 'd': 0},
      }),
    );
    expect(rows.map((r) => r.key), ['a', 'b', 'c', 'd']);
    expect(rows.map((r) => r.value), [100, 100, 30, 0]);
  });

  for (final state in [
    {'schemaVersion': 1},
    {'schemaVersion': 1, 'contributions': null},
    {'schemaVersion': 1, 'contributions': <String, int>{}},
  ]) {
    test('accepts an empty/legacy contribution map: $state', () {
      final repository = AstHomeContributionRepository();
      addTearDown(repository.close);
      expect(repository.decode(jsonEncode(state)), isEmpty);
    });
  }

  for (final source in [
    '<html>not JSON</html>',
    '[]',
    '{"schemaVersion":2,"contributions":{}}',
    '{"schemaVersion":1,"contributions":[]}',
    '{"schemaVersion":1,"contributions":{"a":-1}}',
    '{"schemaVersion":1,"contributions":{"a":1.5}}',
    '{"schemaVersion":1,"contributions":{"a":"30"}}',
    '{"schemaVersion":1,"contributions":{"a":null}}',
    '{"schemaVersion":1,"contributions":{" ":30}}',
  ]) {
    test('rejects malformed totals rather than displaying zero: $source', () {
      final repository = AstHomeContributionRepository();
      addTearDown(repository.close);
      expect(() => repository.decode(source), throwsFormatException);
    });
  }

  test(
    'missing file before the first purchase is an empty leaderboard',
    () async {
      final repository = AstHomeContributionRepository(
        client: MockClient((_) async => http.Response('Not Found', 404)),
      );
      addTearDown(repository.close);
      expect(await repository.fetch(), isEmpty);
    },
  );

  for (final status in [403, 429, 500]) {
    test('HTTP $status is an error, not an empty leaderboard', () async {
      var requests = 0;
      final repository = AstHomeContributionRepository(
        client: MockClient((_) async {
          requests++;
          return http.Response('Unavailable', status);
        }),
      );
      addTearDown(repository.close);
      await expectLater(repository.fetch(), throwsStateError);
      expect(requests, 1); // No fallback to a wallet or Apps Script endpoint.
    });
  }

  test('a stalled read times out', () async {
    final pending = Completer<http.Response>();
    final repository = AstHomeContributionRepository(
      client: MockClient((_) => pending.future),
      timeout: const Duration(milliseconds: 1),
    );
    addTearDown(repository.close);
    await expectLater(repository.fetch(), throwsA(isA<TimeoutException>()));
    pending.complete(http.Response('{"schemaVersion":1}', 200));
  });
}
