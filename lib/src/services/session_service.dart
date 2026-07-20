import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class SessionService {
  static const _teamPassword = 'harmony2026';
  static const _activeIdKey = 'active_login_id';

  bool matchesTeamPassword(String password) => password == _teamPassword;

  Future<UserProfile?> currentProfile() async {
    final preferences = await SharedPreferences.getInstance();
    final id = preferences.getString(_activeIdKey);
    if (id == null) return null;
    return UserProfile(
      loginId: id,
      nickname: preferences.getString('nickname_$id'),
      role: id == 'admin' ? 'admin' : 'member',
    );
  }

  Future<UserProfile> signIn(String rawId) async {
    final id = rawId.trim().toLowerCase();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_activeIdKey, id);
    return UserProfile(
      loginId: id,
      nickname: preferences.getString('nickname_$id'),
      role: id == 'admin' ? 'admin' : 'member',
    );
  }

  Future<UserProfile> registerNickname(String id, String nickname) async {
    final preferences = await SharedPreferences.getInstance();
    final cleanedNickname = nickname.trim();
    await preferences.setString('nickname_$id', cleanedNickname);
    return UserProfile(
      loginId: id,
      nickname: cleanedNickname,
      role: id == 'admin' ? 'admin' : 'member',
    );
  }

  Future<void> signOut() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_activeIdKey);
  }
}
