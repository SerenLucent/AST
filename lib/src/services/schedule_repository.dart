import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_entry.dart';

class ScheduleRepository {
  static const _url =
      'https://api.github.com/repos/SerenLucent/AST/contents/remote-data/schedule.json';
  static const _cacheKey = 'schedule_json_cache';

  Future<List<ScheduleEntry>> fetch({bool forceRefresh = false}) async {
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
      if (response.statusCode != 200) {
        throw Exception('GitHub response: ${response.statusCode}');
      }
      final apiBody = jsonDecode(response.body) as Map<String, dynamic>;
      final encoded = (apiBody['content'] as String).replaceAll('\n', '');
      final source = utf8.decode(base64Decode(encoded));
      await preferences.setString(_cacheKey, source);
      return decode(source);
    } catch (_) {
      final cached = preferences.getString(_cacheKey);
      if (cached != null && !forceRefresh) return decode(cached);
      rethrow;
    }
  }

  List<ScheduleEntry> decode(String source) {
    final body = jsonDecode(source) as Map<String, dynamic>;
    final entries =
        (body['schedules'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ScheduleEntry.fromJson)
            .toList();
    entries.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return entries;
  }
}
