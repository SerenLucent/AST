import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/team_user.dart';
import 'public_github_service.dart';

class UserRepository {
  static const _cacheKey = 'team_users_cache';

  Future<List<TeamUser>> fetch({bool forceRefresh = false}) async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final source = await PublicGithubService().fetchText(
        'remote-data/users.json',
        timeout: const Duration(seconds: 5),
      );
      await preferences.setString(_cacheKey, source);
      return decode(source);
    } catch (_) {
      final cached = preferences.getString(_cacheKey);
      if (cached != null && !forceRefresh) return decode(cached);
      rethrow;
    }
  }

  List<TeamUser> decode(String source) {
    final body = jsonDecode(source) as Map<String, dynamic>;
    return (body['users'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(TeamUser.fromJson)
        .toList();
  }
}
