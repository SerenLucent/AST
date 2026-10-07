import 'dart:convert';
import 'package:http/http.dart' as http;

class GameScoreService {
  GameScoreService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const url = String.fromEnvironment('AST_GAME_SCORE_URL');
  static const key = String.fromEnvironment('AST_GAME_SCORE_KEY');

  Future<void> save(String loginId, Map<String, dynamic> result) async {
    if (url.isEmpty || key.isEmpty) throw StateError('점수 서버 설정이 없습니다.');
    final request =
        http.Request('POST', Uri.parse(url))
          ..followRedirects = false
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({
            'appKey': key,
            'loginId': loginId,
            'result': result,
          });
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 40));
    var response = await http.Response.fromStream(streamed);
    if ([301, 302, 303].contains(response.statusCode)) {
      final location = response.headers['location'];
      if (location == null) throw StateError('점수 서버 응답 오류');
      response = await _client
          .get(Uri.parse(url).resolve(location))
          .timeout(const Duration(seconds: 40));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['ok'] != true) {
      throw StateError(body['error']?.toString() ?? '점수를 저장하지 못했습니다.');
    }
  }

  void dispose() => _client.close();
}
