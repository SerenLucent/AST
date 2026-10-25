import 'dart:async';
import 'package:ast_team_web/src/models/team_user.dart';
import 'package:ast_team_web/src/screens/member_management_screen.dart';
import 'package:ast_team_web/src/services/user_repository.dart';
import 'package:ast_team_web/src/services/web_access_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Users extends UserRepository {
  @override
  Future<List<TeamUser>> fetch({bool forceRefresh = false}) async => [
    for (final id in ['alice', 'bob']) TeamUser(loginId: id, nickname: id,
      registeredAt: DateTime(2026), lastLoginAt: DateTime(2026, 10, id == 'bob' ? 24 : 23, 10)),
  ];
}

class _Access extends WebAccessRepository {
  bool needsAuth = false;
  bool fails = false;
  bool closed = false;
  int calls = 0;
  Future<Map<String, DateTime>>? pending;
  Map<String, DateTime> dates = {'alice': DateTime(2026, 10, 25, 9, 30)};
  @override
  Future<Map<String, DateTime>> fetch() async {
    calls++;
    if (needsAuth) throw const WebAccessAuthRequired();
    if (fails) throw Exception('offline');
    return pending ?? dates;
  }
  @override
  Future<void> authenticate(String id, String password) async {
    if (id != 'admin_naokist' || password != 'test-only') throw const WebAccessException('인증 실패');
    needsAuth = false;
  }
  @override
  void close() { closed = true; }
}

Future<void> _open(WidgetTester tester, _Access access) async {
  await tester.pumpWidget(MaterialApp(home: MemberManagementScreen(
    userRepository: _Users(), webAccessRepository: access)));
  await tester.pump();
}

void main() {
  testWidgets('app/web dates are separate; latest of either sorts first', (tester) async {
    final access = _Access();
    await _open(tester, access); await tester.pumpAndSettle();
    expect(find.textContaining('앱 최근 접속: 2026.10.23 10:00'), findsOneWidget);
    expect(find.textContaining('웹 최근 접속: 2026.10.25 09:30'), findsOneWidget);
    expect(find.textContaining('웹 최근 접속: 기록 없음'), findsOneWidget);
    expect(tester.getTopLeft(find.text('alice')).dy, lessThan(tester.getTopLeft(find.text('bob')).dy));
    await tester.pumpWidget(const SizedBox());
    expect(access.closed, isTrue);
  });
  testWidgets('report failure is not shown as no activity and does not hide app users', (tester) async {
    await _open(tester, _Access()..fails = true); await tester.pumpAndSettle();
    expect(find.text('alice'), findsOneWidget);
    expect(find.textContaining('웹 최근 접속: 조회 실패'), findsNWidgets(2));
    expect(find.textContaining('웹 최근 접속: 기록 없음'), findsNothing);
  });
  testWidgets('slow web report does not block native member list', (tester) async {
    final pending = Completer<Map<String, DateTime>>();
    await _open(tester, _Access()..pending = pending.future);
    expect(find.text('alice'), findsOneWidget);
    expect(find.textContaining('웹 최근 접속: 확인 중'), findsNWidgets(2));
    pending.complete({}); await tester.pumpAndSettle();
  });
  testWidgets('refresh fetches updated records without touching users', (tester) async {
    final access = _Access(); await _open(tester, access); await tester.pumpAndSettle();
    access.dates = {'alice': DateTime(2026, 10, 25, 10, 45)};
    await tester.tap(find.byTooltip('접속 기록 새로고침')); await tester.pumpAndSettle();
    expect(access.calls, 2);
    expect(find.textContaining('웹 최근 접속: 2026.10.25 10:45'), findsOneWidget);
  });
  testWidgets('Android prompts for web admin authentication then loads private report', (tester) async {
    final access = _Access()..needsAuth = true;
    await _open(tester, access); await tester.pumpAndSettle();
    expect(find.textContaining('웹 최근 접속: 관리자 인증 필요'), findsNWidgets(2));
    await tester.tap(find.text('웹 접속 기록: 웹 관리자 인증')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'test-only');
    await tester.tap(find.text('인증')); await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('웹 최근 접속: 2026.10.25 09:30'), findsOneWidget);
  });
}
