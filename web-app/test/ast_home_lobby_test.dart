import 'dart:async';
import 'dart:convert';

import 'package:ast_team_web/src/models/team_user.dart';
import 'package:ast_team_web/src/screens/ast_home_lobby_screen.dart';
import 'package:ast_team_web/src/services/ast_home_contribution_repository.dart';
import 'package:ast_team_web/src/services/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class StubUsers extends UserRepository {
  StubUsers(this.handler);
  final Future<List<TeamUser>> Function() handler;
  int calls = 0;

  @override
  Future<List<TeamUser>> fetch({bool forceRefresh = false}) {
    calls++;
    return handler();
  }
}

TeamUser user(String id, String nickname) => TeamUser(
  loginId: id,
  nickname: nickname,
  registeredAt: DateTime.utc(2026),
  lastLoginAt: DateTime.utc(2026),
);

http.Response stateResponse(Map<String, int> contributions) => http.Response(
  jsonEncode({'schemaVersion': 1, 'contributions': contributions}),
  200,
);

Future<void> showLobby(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
  StubUsers users,
) async {
  final repository = AstHomeContributionRepository(
    client: MockClient((request) {
      expect(request.method, 'GET');
      expect(request.url.host, 'raw.githubusercontent.com');
      expect(request.url.path, endsWith('/games/ast-home/state.json'));
      expect(request.body, isEmpty);
      return handler(request);
    }),
  );
  addTearDown(repository.close);
  await tester.pumpWidget(
    MaterialApp(
      home: AstHomeLobbyScreen(
        loginId: 'tester',
        repository: repository,
        userRepository: users,
      ),
    ),
  );
}

void main() {
  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    testWidgets('shows sorted totals and nicknames at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showLobby(
        tester,
        (_) async => stateResponse({'tester': 30, 'other': 100}),
        StubUsers(() async => [user(' TESTER ', '테스터'), user('other', '팀원')]),
      );
      await tester.pumpAndSettle();
      expect(find.text('테스터'), findsOneWidget);
      expect(find.text('팀원'), findsOneWidget);
      expect(find.text('30 AST'), findsOneWidget);
      expect(find.text('100 AST'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('팀원')).dy,
        lessThan(tester.getTopLeft(find.text('테스터')).dy),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(
        tester.getBottomRight(find.text('집 꾸미기 입장')).dy,
        lessThan(size.height),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nickname request runs in parallel and never delays totals', (
    tester,
  ) async {
    final totals = Completer<http.Response>();
    final names = Completer<List<TeamUser>>();
    final users = StubUsers(() => names.future);
    var reads = 0;
    await showLobby(tester, (_) {
      reads++;
      return totals.future;
    }, users);
    await tester.pump();
    expect(reads, 1);
    expect(users.calls, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    totals.complete(stateResponse({'tester': 30}));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('30 AST'), findsOneWidget);
    expect(find.text('tester'), findsOneWidget);
    names.complete([user('tester', '테스터')]);
    await tester.pumpAndSettle();
    expect(find.text('테스터'), findsOneWidget);
    expect(find.text('tester'), findsNothing);
  });

  testWidgets(
    'nickname failure leaves the contribution and game entry usable',
    (tester) async {
      await showLobby(
        tester,
        (_) async => stateResponse({'tester': 30}),
        StubUsers(() async => throw StateError('offline')),
      );
      await tester.pumpAndSettle();
      expect(find.text('tester'), findsOneWidget);
      expect(find.text('30 AST'), findsOneWidget);
      expect(find.text('기여도를 불러오지 못했습니다.'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'failed contribution read can retry and does not block game entry',
    (tester) async {
      var reads = 0;
      await showLobby(
        tester,
        (_) async =>
            ++reads == 1
                ? http.Response('Unavailable', 500)
                : stateResponse({'tester': 30}),
        StubUsers(() async => []),
      );
      await tester.pumpAndSettle();
      expect(find.text('기여도를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.text('아직 기여 기록이 없습니다.'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('30 AST'), findsOneWidget);
      expect(find.text('기여도를 불러오지 못했습니다.'), findsNothing);
    },
  );

  testWidgets('empty contributions do not block the first furniture purchase', (
    tester,
  ) async {
    await showLobby(
      tester,
      (_) async => http.Response('Not Found', 404),
      StubUsers(() async => []),
    );
    await tester.pumpAndSettle();
    expect(find.text('아직 기여 기록이 없습니다.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('late nickname response from an older refresh is ignored', (
    tester,
  ) async {
    final oldNames = Completer<List<TeamUser>>();
    var nameReads = 0;
    var reads = 0;
    await showLobby(
      tester,
      (_) async => stateResponse({'tester': 30 * ++reads}),
      StubUsers(
        () =>
            ++nameReads == 1
                ? oldNames.future
                : Future.value([user('tester', '새 닉네임')]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('60 AST'), findsOneWidget);
    expect(find.text('새 닉네임'), findsOneWidget);
    oldNames.complete([user('tester', '이전 닉네임')]);
    await tester.pumpAndSettle();
    expect(find.text('새 닉네임'), findsOneWidget);
    expect(find.text('이전 닉네임'), findsNothing);
  });

  testWidgets(
    'leaving while requests are pending never updates disposed state',
    (tester) async {
      final totals = Completer<http.Response>();
      final names = Completer<List<TeamUser>>();
      await showLobby(
        tester,
        (_) => totals.future,
        StubUsers(() => names.future),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      totals.complete(stateResponse({'tester': 30}));
      names.complete([user('tester', '테스터')]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
