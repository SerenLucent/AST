import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_file.dart';

class HistoryRepository {
  static const _apiUrl =
      'https://api.github.com/repos/SerenLucent/AST/contents/Doc?ref=main';
  static const _cacheKey = 'github_doc_folder_cache';
  static const _supportedExtensions = {'pdf', 'ppt', 'pptx', 'doc', 'docx'};

  Future<List<HistoryFile>> fetchFiles({bool forceRefresh = false}) async {
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
      return decodeHistoryFiles(response.body);
    } catch (_) {
      final cached = preferences.getString(_cacheKey);
      if (cached != null && !forceRefresh) return decodeHistoryFiles(cached);
      rethrow;
    }
  }

  List<HistoryFile> decodeHistoryFiles(String source) {
    final items = jsonDecode(source) as List<dynamic>;
    final files =
        items
            .cast<Map<String, dynamic>>()
            .where((item) {
              final name = item['name'] as String;
              final extension =
                  name.contains('.') ? name.split('.').last.toLowerCase() : '';
              return item['type'] == 'file' &&
                  item['download_url'] != null &&
                  _supportedExtensions.contains(extension);
            })
            .map(HistoryFile.fromJson)
            .toList();
    files.sort(compareHistoryFiles);
    return files;
  }
}

DateTime? historyDateFromName(String name) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(name);
  if (match == null) return null;
  return DateTime.tryParse(
    '${match.group(1)}-${match.group(2)}-${match.group(3)}',
  );
}

int compareHistoryFiles(HistoryFile a, HistoryFile b) {
  final aDate = historyDateFromName(a.name);
  final bDate = historyDateFromName(b.name);
  if (aDate != null && bDate != null) return bDate.compareTo(aDate);
  if (aDate != null) return -1;
  if (bDate != null) return 1;
  return b.name.toLowerCase().compareTo(a.name.toLowerCase());
}
