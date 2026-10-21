// Web backend owns verified profiles; never save a whole users.json from login.
class UserRegistryService {
  Future<void> recordLogin({required String loginId, String? nickname}) async {}
  Future<void> updateNickname({required String loginId, required String nickname}) async {}
}
