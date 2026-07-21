import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ast_team_app/src/app.dart';

void main() {
  testWidgets('앱 시작 타이틀은 터치할 때까지 전체 이미지로 표시한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AstTeamApp());

    expect(find.byKey(const ValueKey('title-splash-image')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('title-splash-image')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('title-splash')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login')), findsOneWidget);
  });

  testWidgets('로그인 화면을 표시한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AstTeamApp());
    await tester.tap(find.byKey(const ValueKey('title-splash')));
    await tester.pumpAndSettle();

    expect(find.text('우리의 목소리를 한곳에'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
  });

  testWidgets('로그아웃 버튼을 누르면 로그인 화면으로 돌아간다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'active_login_id': 'test001',
      'nickname_test001': '테스트',
    });
    await tester.pumpWidget(const AstTeamApp());
    await tester.tap(find.byKey(const ValueKey('title-splash')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login')), findsOneWidget);
    expect(find.byKey(const ValueKey('home')), findsNothing);
  });

  testWidgets('내 정보에서 닉네임을 변경한다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'active_login_id': 'test001',
      'nickname_test001': '기존이름',
    });
    await tester.pumpWidget(const AstTeamApp());
    await tester.tap(find.byKey(const ValueKey('title-splash')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline).last);
    await tester.pumpAndSettle();
    expect(find.text('닉네임 변경'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '새이름');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('nickname_test001'), '새이름');
  });
}
