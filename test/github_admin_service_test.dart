import 'package:ast_team_app/src/services/github_admin_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('GitHub token is saved, replaced, and cleared locally', () async {
    SharedPreferences.setMockInitialValues({});
    final service = GithubAdminService();

    await service.saveToken('github_pat_first');
    expect(await service.token, 'github_pat_first');

    await service.saveToken('github_pat_second');
    expect(await service.token, 'github_pat_second');

    await service.clearToken();
    expect(await service.token, isNull);
  });
}
