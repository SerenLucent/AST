import 'dart:convert';

import 'package:http/http.dart' as http;

/// Read-only leaderboard data. Never used as a wallet or purchase authority.
class AstHomeContributionRepository {
  AstHomeContributionRepository({
    http.Client? client,
    Duration timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _timeout = timeout;

  final http.Client _client;
  final Duration _timeout;

  Future<List<MapEntry<String, int>>> fetch() async {
    // Raw avoids both the Apps Script round trip and the public Contents API
    // rate limit. Refresh/return from the game requests a new snapshot.
    final uri = Uri.https(
      'raw.githubusercontent.com',
      '/SerenLucent/AST/main/remote-data/games/ast-home/state.json',
      {'v': DateTime.now().microsecondsSinceEpoch.toString()},
    );
    final response = await _client
        .get(
          uri,
          // Only CORS-safelisted headers: the unique query bypasses stale URLs
          // without introducing a browser preflight to GitHub Raw.
          headers: const {'Accept': 'application/json'},
        )
        .timeout(_timeout);
    // The server creates state.json only after the first furniture purchase.
    if (response.statusCode == 404) return [];
    if (response.statusCode != 200) {
      throw StateError('기여도를 불러오지 못했습니다. (${response.statusCode})');
    }
    return decode(utf8.decode(response.bodyBytes));
  }

  List<MapEntry<String, int>> decode(String source) {
    final body = jsonDecode(source);
    if (body is! Map<String, dynamic> || body['schemaVersion'] != 1) {
      throw const FormatException('Invalid home contribution data');
    }
    final totals = body['contributions'] ?? <String, dynamic>{};
    if (totals is! Map<String, dynamic>) {
      throw const FormatException('Invalid home contributions');
    }
    final rows = <MapEntry<String, int>>[];
    for (final entry in totals.entries) {
      final value = entry.value;
      if (entry.key.trim().isEmpty || value is! int || value < 0) {
        throw const FormatException('Invalid home contribution');
      }
      rows.add(MapEntry(entry.key, value));
    }
    rows.sort((a, b) {
      final order = b.value.compareTo(a.value);
      return order != 0 ? order : a.key.compareTo(b.key);
    });
    return rows;
  }

  void close() => _client.close();
}
