import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/notice.dart';
import 'public_github_service.dart';

class NoticeRepository {
  const NoticeRepository.notices()
    : _fileName = 'notices.json',
      _cacheKey = 'notices_cache';

  const NoticeRepository.board()
    : _fileName = 'board.json',
      _cacheKey = 'board_posts_cache';

  final String _fileName;
  final String _cacheKey;

  Future<List<Notice>> fetch({bool forceRefresh = false}) async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final source = await PublicGithubService().fetchText(
        'remote-data/$_fileName',
      );
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
