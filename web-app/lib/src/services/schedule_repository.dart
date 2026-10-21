import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_entry.dart';
import 'public_github_service.dart';

class ScheduleRepository {
  static const _cacheKey = 'schedule_json_cache';

  Future<List<ScheduleEntry>> fetch({bool forceRefresh = false}) async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final source = await PublicGithubService().fetchText(
        'remote-data/schedule.json',
      );
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
