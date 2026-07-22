import 'package:ast_team_app/src/services/github_admin_service.dart';
import 'package:ast_team_app/src/widgets/github_token_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('내장 GitHub token은 로컬 변경을 지운 뒤 다시 사용된다', () async {
    SharedPreferences.setMockInitialValues({});
    final service = GithubAdminService();

    await service.saveToken('github_pat_first');
    expect(await service.token, 'github_pat_first');

    await service.saveToken('github_pat_second');
    expect(await service.token, 'github_pat_second');

    await service.clearToken();
    expect(await service.token, isNotNull);
  });

  testWidgets('token dialog closes immediately after pressing save', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = GithubAdminService();
    await service.clearToken();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => showGithubTokenDialog(context, service),
                  child: const Text('토큰 입력'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('토큰 입력'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'github_pat_test_value');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(await service.token, 'github_pat_test_value');
  });
}
