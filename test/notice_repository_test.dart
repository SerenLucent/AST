import 'package:ast_team_app/src/screens/notice_screen.dart';
import 'package:ast_team_app/src/services/notice_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('notices are decoded in newest-first order', () {
    final notices = NoticeRepository().decode('''
      {"schemaVersion":1,"notices":[
        {"id":"old","title":"이전","memo":"내용","createdAt":"2026-07-20T10:00:00","authorId":"a","authorNickname":"A"},
        {"id":"new","title":"최신","memo":"내용","createdAt":"2026-07-21T10:00:00","authorId":"b","authorNickname":"B"}
      ]}
    ''');

    expect(notices.map((notice) => notice.id), ['new', 'old']);
  });

  testWidgets('every user can see notice add button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: NoticeScreen(loginId: 'member', nickname: '멤버')),
    );
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('작성'), findsOneWidget);
  });
}
