import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class SessionService {
  static const _activeIdKey = 'active_login_id';
  static const _accessCacheKey = 'team_access_cache';
  static const _configUrl =
      'https://api.github.com/repos/SerenLucent/AST/contents/remote-data/main.json';

  Future<bool> canSignIn(String rawId, String password) async {
    final access = await _loadAccess();
    if (password != access['teamPassword']) return false;
    if (access['login_all'] == 'Y') return true;
    final id = rawId.trim().toLowerCase();
    final allowedIds =
        (access['allowedIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map((allowedId) => allowedId.trim().toLowerCase())
            .toSet();
    return allowedIds.contains(id);
  }

  Future<Map<String, dynamic>> _loadAccess() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final response = await http
          .get(
            Uri.parse(_configUrl).replace(
              queryParameters: {
                'ref': 'main',
                'cacheBust': '${DateTime.now().microsecondsSinceEpoch}',
              },
            ),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) throw Exception('config unavailable');
      final apiBody = jsonDecode(response.body) as Map<String, dynamic>;
      final encoded = (apiBody['content'] as String).replaceAll('\n', '');
      final config =
          jsonDecode(utf8.decode(base64Decode(encoded)))
              as Map<String, dynamic>;
      final access = _accessFrom(config);
      await preferences.setString(_accessCacheKey, jsonEncode(access));
      return access;
    } catch (_) {
      final cached = preferences.getString(_accessCacheKey);
      if (cached != null) {
        return jsonDecode(cached) as Map<String, dynamic>;
      }
      final bundled =
          jsonDecode(await rootBundle.loadString('remote-data/main.json'))
              as Map<String, dynamic>;
      return _accessFrom(bundled);
    }
  }

  Map<String, dynamic> _accessFrom(Map<String, dynamic> config) {
    final access = config['access'] as Map<String, dynamic>?;
    final password = access?['teamPassword'] as String?;
    if (password == null || password.isEmpty) {
      throw const FormatException('teamPassword is missing');
    }
    return access!;
  }

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
