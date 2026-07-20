import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ast_team_app/src/app.dart';

void main() {
  testWidgets('로그인 화면을 표시한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AstTeamApp());
    await tester.pumpAndSettle();

    expect(find.text('우리의 목소리를 한곳에'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
  });

  testWidgets('프로필 버튼으로 로그아웃하면 로그인 화면으로 돌아간다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'active_login_id': 'test001',
      'nickname_test001': '테스트',
    });
    await tester.pumpWidget(const AstTeamApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CircleAvatar).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login')), findsOneWidget);
    expect(find.byKey(const ValueKey('home')), findsNothing);
  });
}
