import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class GameRankingEntry {
  const GameRankingEntry({
    required this.playerKey,
    required this.nickname,
    required this.bestScore,
  });
  final String playerKey;
  final String nickname;
  final int bestScore;
}

class GameRankingRepository {
  GameRankingRepository({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  static String playerKeyFor(String loginId) =>
      sha256.convert(utf8.encode(loginId.trim().toLowerCase())).toString();

  Future<List<GameRankingEntry>> fetch() async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/SerenLucent/AST/contents/remote-data/games/timing-shooter-scores.json',
      {
        'ref': 'main',
        'cacheBust': DateTime.now().microsecondsSinceEpoch.toString(),
      },
    );
    final response = await _client
        .get(
          uri,
          headers: const {
            'Accept': 'application/vnd.github+json',
            'Cache-Control': 'no-cache',
            'User-Agent': 'AST-Android-App',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw StateError('랭킹을 불러오지 못했습니다.');
    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    final encoded = (envelope['content'] as String).replaceAll(
      RegExp(r'\s'),
      '',
    );
    return decode(utf8.decode(base64Decode(encoded)));
  }

  List<GameRankingEntry> decode(String source) {
    final body = jsonDecode(source) as Map<String, dynamic>;
    if (body['schemaVersion'] != 1 || body['game'] != 'timing-shooter')
      throw const FormatException('Invalid ranking');
    final rows =
        (body['players'] as List<dynamic>).map((value) {
          final row = value as Map<String, dynamic>;
          final bestScore = row['bestScore'];
          if (bestScore is! int || bestScore < 0)
            throw const FormatException('Invalid score');
          return GameRankingEntry(
            playerKey: row['playerKey'] as String,
            nickname: row['nickname'] as String? ?? 'Player',
            bestScore: bestScore,
          );
        }).toList();
    rows.sort((a, b) {
      final scoreOrder = b.bestScore.compareTo(a.bestScore);
      return scoreOrder != 0 ? scoreOrder : a.playerKey.compareTo(b.playerKey);
    });
    return rows;
  }

  void dispose() => _client.close();
}
