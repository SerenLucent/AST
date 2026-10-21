import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ApkInstaller {
  static const _channel = MethodChannel('com.ast.acappella/apk_installer');
  Future<void> downloadAndInstall(
    String url, {
    required void Function(double) onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send().timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('APK 다운로드 실패 (${response.statusCode})');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      if (response.contentLength case final total? when total > 0) {
        onProgress(bytes.length / total);
      }
    }
    if (bytes.length < 1024 || !updateLooksLikeApk(bytes)) {
      throw Exception('올바른 APK 파일이 아닙니다.');
    }
    await _channel.invokeMethod<void>('installApk', {
      'bytes': Uint8List.fromList(bytes),
    });
  }

  bool updateLooksLikeApk(List<int> bytes) =>
      bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
}
