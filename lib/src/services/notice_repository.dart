import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notice.dart';

class NoticeRepository {
  const NoticeRepository.notices()
    : _fileName = 'notices.json',
      _cacheKey = 'notices_cache';

  const NoticeRepository.board()
    : _fileName = 'board.json',
      _cacheKey = 'board_posts_cache';

  final String _fileName;
  final String _cacheKey;

  String get _url =>
      'https://api.github.com/repos/SerenLucent/AST/contents/remote-data/$_fileName';

  Future<List<Notice>> fetch({bool forceRefresh = false}) async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final response = await http.get(
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
          'Pragma': 'no-cache',
        },
      );
      if (response.statusCode == 404) return [];
      if (response.statusCode != 200) {
        throw Exception('GitHub response: ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final encoded = (body['content'] as String).replaceAll('\n', '');
      final source = utf8.decode(base64Decode(encoded));
      await preferences.setString(_cacheKey, source);
      return decode(source);
    } catch (_) {
      final cached = preferences.getString(_cacheKey);
      if (cached != null && !forceRefresh) return decode(cached);
      rethrow;
    }
  }

  List<Notice> decode(String source) {
    final body = jsonDecode(source) as Map<String, dynamic>;
    final notices =
        (body['notices'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Notice.fromJson)
            .toList();
    notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notices;
  }
}
