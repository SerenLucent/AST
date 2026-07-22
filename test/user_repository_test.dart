import 'package:ast_team_app/src/services/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('사용자 권한 JSON을 읽는다', () {
    final users = UserRepository().decode('''
      {"schemaVersion":1,"users":[{
        "loginId":"leader",
        "nickname":"팀장",
        "registeredAt":"2026-07-22T01:00:00Z",
        "lastLoginAt":"2026-07-22T02:00:00Z",
        "canUploadScores":true,
        "canUploadHistory":false
      }]}
    ''');

    expect(users.single.loginId, 'leader');
    expect(users.single.nickname, '팀장');
    expect(users.single.canUploadScores, isTrue);
    expect(users.single.canUploadHistory, isFalse);
  });
}
