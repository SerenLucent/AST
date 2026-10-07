import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ast_team_app/src/services/game_version_service.dart';
import 'package:ast_team_app/src/services/game_ranking_repository.dart';
import 'package:ast_team_app/src/screens/game_lobby_screen.dart';

GameVersionService versions(
  String current, {
  String latest = '3.0.7',
  int code = 200,
}) => GameVersionService(
  installedVersion: () async => current,
  client: MockClient((request) async {
    expect(request.url.path, endsWith('/update/version.json'));
    expect(request.url.queryParameters['cacheBust'], isNotEmpty);
    return http.Response(
      jsonEncode({
        'content': base64Encode(
          utf8.encode(jsonEncode({'versionName': latest})),
        ),
      }),
      code,
    );
  }),
);

void main() {
  test(
    'installed package version must meet latest published version',
    () async {
      for (final current in ['3.0.6', '3.0.7', '3.0.10']) {
        final service = versions(current);
        final status = await service.check();
        expect(status.allowed, current != '3.0.6');
        service.dispose();
      }
      expect(
        () => const GameVersionStatus('3.0.7', '').allowed,
        throwsFormatException,
      );
    },
  );

  for (final failure in [false, true]) {
    testWidgets(
      failure
          ? 'network failure blocks launch and permits retry'
          : 'outdated app blocks launch with version dialog',
      (tester) async {
        final service = versions('3.0.6', code: failure ? 503 : 200);
        final ranking = GameRankingRepository(
          client: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'content': base64Encode(
                  utf8.encode(
                    jsonEncode({
                      'schemaVersion': 1,
                      'game': 'timing-shooter',
                      'players': [],
                    }),
                  ),
                ),
              }),
              200,
            ),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: GameLobbyScreen(
              loginId: 'tester',
              nickname: 'Tester',
              repository: ranking,
              versionService: service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('게임 시작'));
        await tester.pumpAndSettle();
        if (failure) {
          expect(find.textContaining('앱 버전을 확인할 수 없습니다.'), findsOneWidget);
        } else {
          expect(find.text('앱 업데이트가 필요합니다'), findsOneWidget);
          expect(find.textContaining('현재 버전: 3.0.6'), findsOneWidget);
          await tester.tap(find.text('확인'));
          await tester.pumpAndSettle();
        }
        expect(find.text('게임 시작'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        service.dispose();
        ranking.dispose();
      },
    );
  }
}
