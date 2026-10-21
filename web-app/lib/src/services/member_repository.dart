import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/member_profile.dart';
import 'public_github_service.dart';

class MemberRepository {
  static const _cacheKey = 'member_profiles_cache';

  Future<Map<String, String>> fetchGenerationColors() async {
    const defaults = {
      '1기': '#E57373',
      '2기': '#64B5F6',
      '3기': '#81C784',
      '4기': '#BA68C8',
      'Guest': '#FFB74D',
    };
    try {
      final source = await PublicGithubService().fetchText(
        'remote-data/main.json',
        timeout: const Duration(seconds: 5),
      );
      final config = jsonDecode(source) as Map<String, dynamic>;
      return (config['memberGenerationColors'] as Map<String, dynamic>? ??
              defaults)
          .map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return defaults;
    }
  }

  Future<List<MemberProfile>> fetch({bool forceRefresh = false}) async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final source = await PublicGithubService().fetchText(
        'remote-data/members.json',
      );
      await preferences.setString(_cacheKey, source);
      return decode(source);
    } catch (_) {
      final cached = preferences.getString(_cacheKey);
      if (cached != null && !forceRefresh) return decode(cached);
      rethrow;
    }
  }

  List<MemberProfile> decode(String source) {
    final body = jsonDecode(source) as Map<String, dynamic>;
    return (body['members'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(MemberProfile.fromJson)
        .toList();
  }
}
