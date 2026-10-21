import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/score_file.dart';

class ScoreRepository {
  static const _apiUrl =
      'https://api.github.com/repos/SerenLucent/AST/contents/Music?ref=main';
  static const _cacheKey = 'github_music_folder_cache';

  Future<List<ScoreFile>> fetchScores({bool forceRefresh = false}) async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );
      if (response.statusCode != 200) {
        throw Exception('GitHub response: ${response.statusCode}');
      }
      await preferences.setString(_cacheKey, response.body);
      return _decode(response.body);
    } catch (_) {
      final cached = preferences.getString(_cacheKey);
      if (cached != null && !forceRefresh) return _decode(cached);
      rethrow;
    }
  }

  List<ScoreFile> _decode(String source) {
    final items = jsonDecode(source) as List<dynamic>;
    final scores =
        items
            .cast<Map<String, dynamic>>()
            .where(
              (item) =>
                  item['type'] == 'file' &&
                  (item['name'] as String).toLowerCase().endsWith('.pdf') &&
                  item['download_url'] != null,
            )
            .map(ScoreFile.fromJson)
            .toList();
    scores.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return scores;
  }
}
