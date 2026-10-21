import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class GameVersionStatus {
  const GameVersionStatus(this.current, this.latest);
  final String current;
  final String latest;

  bool get allowed {
    List<int> parts(String value) {
      if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value)) {
        throw const FormatException('Invalid app version');
      }
      return value.split('.').map(int.parse).toList();
    }

    final installed = parts(current), published = parts(latest);
    for (var i = 0; i < 3; i++) {
      if (installed[i] != published[i]) return installed[i] > published[i];
    }
    return true;
  }
}

class GameVersionService {
  GameVersionService({
    http.Client? client,
    Future<String> Function()? installedVersion,
  }) : _client = client ?? http.Client(),
       _installedVersion = installedVersion ?? _readInstalledVersion;
  final http.Client _client;
  final Future<String> Function() _installedVersion;

  static Future<String> _readInstalledVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  Future<GameVersionStatus> check() async {
    final current = await _installedVersion().timeout(
      const Duration(seconds: 8),
    );
    final uri = Uri.https(
      'api.github.com',
      '/repos/SerenLucent/AST/contents/update/version.json',
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
          },
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw Exception('Version check failed');
    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    final content = envelope['content'] as String;
    final manifest =
        jsonDecode(utf8.decode(base64Decode(content.replaceAll('\n', ''))))
            as Map<String, dynamic>;
    final status = GameVersionStatus(
      current,
      manifest['versionName'] as String,
    );
    status.allowed; // Validate the manifest before allowing entry.
    return status;
  }

  void dispose() => _client.close();
}
