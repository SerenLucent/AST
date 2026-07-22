import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/team_user.dart';

class UserRepository {
  static const _url =
      'https://api.github.com/repos/SerenLucent/AST/contents/remote-data/users.json';
  static const _cacheKey = 'team_users_cache';

  Future<List<TeamUser>> fetch({bool forceRefresh = false}) async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final response = await http
          .get(
            Uri.parse(_url).replace(
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
      if (response.statusCode == 404) return [];
      if (response.statusCode != 200) throw Exception('사용자 목록 조회 실패');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final source = utf8.decode(
        base64Decode((body['content'] as String).replaceAll('\n', '')),
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
