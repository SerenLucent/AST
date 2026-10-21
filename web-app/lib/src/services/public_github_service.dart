import 'dart:convert';
import 'package:http/http.dart' as http;
import 'web_api.dart';

class PublicGithubService {
  PublicGithubService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  Future<String> fetchText(String path, {Duration? timeout}) async {
    // Do not download/cache the public main.json containing legacy credentials.
    if (path == 'remote-data/main.json') {
      return jsonEncode((await WebApi.request({'action': 'publicConfig'}))['config']);
    }
    if (!path.startsWith('remote-data/') || path.contains('..')) throw ArgumentError('Invalid data path');
    final uri = Uri.https('raw.githubusercontent.com', '/SerenLucent/AST/main/$path',
      {'v': '${DateTime.now().millisecondsSinceEpoch ~/ 60000}'});
    final r = await _client.get(uri).timeout(timeout ?? const Duration(seconds: 12));
    if (r.statusCode != 200) throw Exception('자료를 불러오지 못했습니다. (${r.statusCode})');
    return utf8.decode(r.bodyBytes);
  }
}
