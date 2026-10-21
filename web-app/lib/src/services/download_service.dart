import 'dart:html' as html;
import 'package:http/http.dart' as http;
import '../models/score_file.dart';
class DownloadService {
  Future<bool> downloadAndSave(ScoreFile score) => downloadAndSaveFile(
    fileName: score.name, downloadUrl: score.downloadUrl, mimeType: 'application/pdf');
  Future<bool> downloadAndSaveFile({required String fileName, required String downloadUrl, required String mimeType}) async {
    final r = await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 45));
    if (r.statusCode != 200) throw Exception('파일을 불러오지 못했습니다.');
    final url = html.Url.createObjectUrlFromBlob(html.Blob([r.bodyBytes], mimeType));
    final a = html.AnchorElement(href: url)..download = fileName;
    html.document.body!.append(a); a.click(); a.remove();
    Future.delayed(const Duration(minutes: 1), () => html.Url.revokeObjectUrl(url));
    return true;
  }
}
