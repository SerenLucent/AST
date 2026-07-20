import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/score_file.dart';

class DownloadService {
  static const _channel = MethodChannel('com.ast.acappella/file_saver');

  Future<bool> downloadAndSave(ScoreFile score) async {
    return downloadAndSaveFile(
      fileName: score.name,
      downloadUrl: score.downloadUrl,
      mimeType: 'application/pdf',
    );
  }

  Future<bool> downloadAndSaveFile({
    required String fileName,
    required String downloadUrl,
    required String mimeType,
  }) async {
    final response = await http.get(Uri.parse(downloadUrl));
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }
    final saved = await _channel.invokeMethod<bool>('saveFile', {
      'fileName': fileName,
      'mimeType': mimeType,
      'bytes': response.bodyBytes,
    });
    return saved ?? false;
  }
}
