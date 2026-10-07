import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ast_team_app/src/screens/game_lobby_screen.dart';
import 'package:ast_team_app/src/services/game_ranking_repository.dart';

GameRankingRepository repository(List<Map<String, Object>> players) =>
    GameRankingRepository(
      client: MockClient((request) async {
        expect(
          request.url.path,
          endsWith('/remote-data/games/timing-shooter/scores.json'),
        );
        final data = jsonEncode({
          'schemaVersion': 1,
          'game': 'timing-shooter',
          'weekStart':
              GameRankingRepository.weekStart(DateTime.now()).toIso8601String(),
          'players': players,
        });
        return http.Response(
          jsonEncode({'content': base64Encode(utf8.encode(data))}),
          200,
        );
      }),
    );

void main() {
  test('weekly ranking hides previous week exactly at Monday midnight KST', () {
    final repo = repository([]);
    final source = jsonEncode({
      'schemaVersion': 1,
      'game': 'timing-shooter',
      'weekStart': '2026-10-04T15:00:00.000Z',
      'players': [
        {'playerKey': 'test', 'nickname': 'Test', 'bestScore': 100},
      ],
    });
    expect(
      repo.decode(source, now: DateTime.parse('2026-10-11T14:59:59.999Z')),
      hasLength(1),
    );
    expect(
      repo.decode(source, now: DateTime.parse('2026-10-11T15:00:00.000Z')),
      isEmpty,
    );
    repo.dispose();
  });
  test('ranking sorts scores and matches normalized login IDs', () async {
    final key = GameRankingRepository.playerKeyFor('Tester');
    expect(GameRankingRepository.playerKeyFor(' tester '), key);
    final repo = repository([
      {'playerKey': key, 'nickname': 'Old nickname', 'bestScore': 1234},
      {'playerKey': 'another', 'nickname': 'First', 'bestScore': 9000},
    ]);
    final rows = await repo.fetch();
    expect(rows.map((row) => row.bestScore), [9000, 1234]);
    expect(rows.last.playerKey, key);
    repo.dispose();
  });

  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    testWidgets('lobby shows nickname, ranking and start button at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = repository([
        {
          'playerKey': GameRankingRepository.playerKeyFor('tester'),
          'nickname': 'Old nickname',
          'bestScore': 1234,
        },
        {'playerKey': 'another', 'nickname': 'First', 'bestScore': 9000},
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: GameLobbyScreen(
            loginId: 'tester',
            nickname: '현재 AST 닉네임',
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('현재 AST 닉네임'), findsNWidgets(2));
      expect(find.text('1,234'), findsNWidgets(2));
      expect(find.text('9,000'), findsOneWidget);
      expect(find.text('게임 시작'), findsOneWidget);
      expect(
        tester.getBottomRight(find.text('게임 시작')).dy,
        lessThan(size.height),
      );
      expect(tester.takeException(), isNull);
      repo.dispose();
    });
  }

  testWidgets('empty ranking keeps game start enabled', (tester) async {
    final repo = repository([]);
    await tester.pumpWidget(
      MaterialApp(
        home: GameLobbyScreen(
          loginId: 'tester',
          nickname: 'Tester',
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('아직 등록된 점수가 없어요.'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    repo.dispose();
  });
}
