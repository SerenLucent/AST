import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import 'web_api.dart';

class SessionService {
  UserProfile? _authenticated;
  Future<bool> canSignIn(String rawId, String password) async {
    _authenticated = null;
    final response = await WebApi.request({
      'action': 'login', 'loginId': rawId.trim().toLowerCase(), 'password': password,
    }, authenticated: false);
    final token = response['sessionToken'];
    if (token is! String || token.length < 32) throw const WebApiException('로그인 응답이 올바르지 않습니다.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WebApi.tokenKey, token);
    _authenticated = _profile(response);
    return true;
  }
  Future<UserProfile?> currentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(WebApi.tokenKey) == null) return null;
    try {
      return _authenticated = _profile(await WebApi.request({'action': 'session'}));
    } on WebApiException catch (e) {
      if (e.code == 'UNAUTHORIZED') return null;
      rethrow; // Network failure must not destroy a valid saved session.
    }
  }
  Future<UserProfile> signIn(String rawId) async {
    final profile = _authenticated;
    if (profile == null || profile.loginId != rawId.trim().toLowerCase()) {
      throw const WebApiException('다시 로그인해 주세요.');
    }
    return profile;
  }
  Future<UserProfile> registerNickname(String id, String nickname) async =>
    _authenticated = _profile(await WebApi.request({'action': 'profile', 'nickname': nickname.trim()}));
  Future<void> signOut() async {
    try { await WebApi.request({'action': 'logout'}, timeout: const Duration(seconds: 8)); }
    catch (_) { /* Local logout still works offline. */ }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(WebApi.tokenKey); await prefs.remove(WebApi.expiryKey);
    _authenticated = null;
  }
  UserProfile _profile(Map<String, dynamic> response) {
    final p = Map<String, dynamic>.from(response['profile'] as Map);
    return UserProfile(loginId: p['loginId'] as String,
      nickname: p['nickname'] as String?, role: p['role'] as String? ?? 'member');
  }
}
