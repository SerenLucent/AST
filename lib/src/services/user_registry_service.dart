import '../models/team_user.dart';
import 'github_admin_service.dart';
import 'user_repository.dart';

class UserRegistryService {
  final _repository = UserRepository();
  final _github = GithubAdminService();

  Future<void> recordLogin({required String loginId, String? nickname}) async {
    final users = await _fetchLatest();
    final now = DateTime.now();
    final index = users.indexWhere(
      (user) => user.loginId.toLowerCase() == loginId.toLowerCase(),
    );
    if (index < 0) {
      users.add(
        TeamUser(
          loginId: loginId,
          nickname: nickname ?? '',
          registeredAt: now,
          lastLoginAt: now,
        ),
      );
    } else {
      users[index] = users[index].copyWith(
        nickname:
            nickname == null || nickname.trim().isEmpty
                ? users[index].nickname
                : nickname.trim(),
        lastLoginAt: now,
      );
    }
    await _github.saveUsers(users);
  }

  Future<void> updateNickname({
    required String loginId,
    required String nickname,
  }) => recordLogin(loginId: loginId, nickname: nickname);

  Future<List<TeamUser>> _fetchLatest() async {
    try {
      return await _repository.fetch(forceRefresh: true);
    } catch (_) {
      return [];
    }
  }
}
