import 'dart:convert';
import '../models/app_update.dart';
import 'public_github_service.dart';

class UpdateRepository {
  static const currentVersion = '3.1.0';
  Future<AppUpdate> fetch() async {
    final source = await PublicGithubService().fetchText('update/version.json');
    return AppUpdate.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }

  String apkUrl(AppUpdate update) {
    if (update.apkUrl.trim().isNotEmpty) return update.apkUrl.trim();
    return Uri.https(
      'raw.githubusercontent.com',
      '/SerenLucent/AST/main/update/${update.apkFile}',
      {'cacheBust': DateTime.now().microsecondsSinceEpoch.toString()},
    ).toString();
  }
}
