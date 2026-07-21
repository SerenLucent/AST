import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class SessionService {
  static const _activeIdKey = 'active_login_id';
  static const _passwordCacheKey = 'team_password_cache';
  static const _configUrl =
      'https://api.github.com/repos/SerenLucent/AST/contents/remote-data/main.json';

  Future<bool> matchesTeamPassword(String password) async {
    final teamPassword = await _loadTeamPassword();
    return password == teamPassword;
  }

  Future<String> _loadTeamPassword() async {
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
      final password = _passwordFrom(config);
      await preferences.setString(_passwordCacheKey, password);
      return password;
    } catch (_) {
      final cached = preferences.getString(_passwordCacheKey);
      if (cached != null && cached.isNotEmpty) return cached;
      final bundled =
          jsonDecode(await rootBundle.loadString('remote-data/main.json'))
              as Map<String, dynamic>;
      return _passwordFrom(bundled);
    }
  }

  String _passwordFrom(Map<String, dynamic> config) {
    final access = config['access'] as Map<String, dynamic>?;
    final password = access?['teamPassword'] as String?;
    if (password == null || password.isEmpty) {
      throw const FormatException('teamPassword is missing');
    }
    return password;
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
