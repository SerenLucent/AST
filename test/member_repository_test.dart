import 'package:ast_team_app/src/screens/member_intro_screen.dart';
import 'package:ast_team_app/src/services/member_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('member JSON is decoded', () {
    final members = MemberRepository().decode('''
      {"schemaVersion":1,"members":[
        {"id":"one","name":"홍길동","imageUrl":"https://example.com/one.jpg","memo":"소프라노"}
      ]}
    ''');

    expect(members.single.id, 'one');
    expect(members.single.name, '홍길동');
    expect(members.single.memo, '소프라노');
  });

  test('member without image is decoded with an empty image URL', () {
    final members = MemberRepository().decode('''
      {"schemaVersion":1,"members":[{"id":"two","memo":"사진 없는 팀원"}]}
    ''');

    expect(members.single.imageUrl, isEmpty);
    expect(members.single.memo, '사진 없는 팀원');
  });

  testWidgets('member cannot see add button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: MemberIntroScreen(isAdmin: false)),
    );
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('admin can see add button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: MemberIntroScreen(isAdmin: true)),
    );
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
