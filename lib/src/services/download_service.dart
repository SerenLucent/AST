import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/score_file.dart';

class DownloadService {
  static const _channel = MethodChannel('com.ast.acappella/file_saver');

  Future<bool> downloadAndSave(ScoreFile score) async {
    final response = await http.get(Uri.parse(score.downloadUrl));
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }
    final saved = await _channel.invokeMethod<bool>('saveFile', {
      'fileName': score.name,
      'mimeType': 'application/pdf',
      'bytes': response.bodyBytes,
    });
    return saved ?? false;
  }
}
