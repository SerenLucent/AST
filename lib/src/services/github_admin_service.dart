import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/score_file.dart';
import '../models/schedule_entry.dart';

class GithubAdminService {
  static const _owner = 'SerenLucent';
  static const _repository = 'AST';
  static const _branch = 'main';
  static const _tokenKey = 'github_admin_token';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> get token => _storage.read(key: _tokenKey);

  Future<void> saveToken(String value) =>
      _storage.write(key: _tokenKey, value: value.trim());

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<bool> validateToken(String value) async {
    final response = await http
        .get(_contentsUri(const ['Music']), headers: _headers(value.trim()))
        .timeout(const Duration(seconds: 10));
    return response.statusCode == 200;
  }

  Future<void> uploadPdf({
    required String fileName,
    required Uint8List bytes,
    String? existingSha,
  }) async {
    if (bytes.length > 50 * 1024 * 1024) {
      throw const GithubAdminException('50MB 이하의 PDF만 업로드할 수 있습니다.');
    }
    final adminToken = await token;
    if (adminToken == null) {
      throw const GithubAdminException('GitHub 연결이 필요합니다.');
    }
    final response = await http.put(
      _contentsUri(['Music', fileName]),
      headers: _headers(adminToken),
      body: jsonEncode({
        'message': '악보 업로드: $fileName',
        'content': base64Encode(bytes),
        'branch': _branch,
        if (existingSha != null) 'sha': existingSha,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw GithubAdminException(_errorMessage(response, '업로드하지 못했습니다.'));
    }
  }

  Future<void> uploadHistoryFile({
    required String fileName,
    required Uint8List bytes,
    String? existingSha,
  }) => _uploadFile(
    folder: 'Doc',
    fileName: fileName,
    bytes: bytes,
    existingSha: existingSha,
    commitLabel: '행사 히스토리 업로드',
  );

  Future<void> saveSchedules(List<ScheduleEntry> schedules) async {
    final adminToken = await token;
    if (adminToken == null) {
      throw const GithubAdminException('일정을 저장하려면 GitHub 연결이 필요합니다.');
    }
    const segments = ['remote-data', 'schedule.json'];
    final current = await http.get(
      _contentsUri(segments),
      headers: _headers(adminToken),
    );
    String? sha;
    if (current.statusCode == 200) {
      sha =
          (jsonDecode(current.body) as Map<String, dynamic>)['sha'] as String?;
    } else if (current.statusCode != 404) {
      throw GithubAdminException(_errorMessage(current, '일정 정보를 확인하지 못했습니다.'));
    }
    final content = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'schedules': schedules.map((entry) => entry.toJson()).toList(),
    });
    final response = await http.put(
      _contentsUri(segments),
      headers: _headers(adminToken),
      body: jsonEncode({
        'message': '일정 업데이트',
        'content': base64Encode(utf8.encode(content)),
        'branch': _branch,
        if (sha != null) 'sha': sha,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw GithubAdminException(_errorMessage(response, '일정을 저장하지 못했습니다.'));
    }
  }

  Future<void> _uploadFile({
    required String folder,
    required String fileName,
    required Uint8List bytes,
    required String commitLabel,
    String? existingSha,
  }) async {
    if (bytes.length > 50 * 1024 * 1024) {
      throw const GithubAdminException('50MB 이하의 파일만 업로드할 수 있습니다.');
    }
    final adminToken = await token;
    if (adminToken == null) {
      throw const GithubAdminException('GitHub 연결이 필요합니다.');
    }
    final response = await http.put(
      _contentsUri([folder, fileName]),
      headers: _headers(adminToken),
      body: jsonEncode({
        'message': '$commitLabel: $fileName',
        'content': base64Encode(bytes),
        'branch': _branch,
        if (existingSha != null) 'sha': existingSha,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw GithubAdminException(_errorMessage(response, '업로드하지 못했습니다.'));
    }
  }

  Future<void> deleteScore(ScoreFile score) async {
    final adminToken = await token;
    if (adminToken == null) {
      throw const GithubAdminException('GitHub 연결이 필요합니다.');
    }
    final response = await http.delete(
      _contentsUri(score.path.split('/')),
      headers: _headers(adminToken),
      body: jsonEncode({
        'message': '악보 삭제: ${score.name}',
        'sha': score.sha,
        'branch': _branch,
      }),
    );
    if (response.statusCode != 200) {
      throw GithubAdminException(_errorMessage(response, '삭제하지 못했습니다.'));
    }
  }

  Uri _contentsUri(List<String> segments) => Uri(
    scheme: 'https',
    host: 'api.github.com',
    pathSegments: ['repos', _owner, _repository, 'contents', ...segments],
    queryParameters: segments.length == 1 ? {'ref': _branch} : null,
  );

  Map<String, String> _headers(String value) => {
    'Accept': 'application/vnd.github+json',
    'Authorization': 'Bearer $value',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json',
  };

  String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return '$fallback (${response.statusCode}: ${body['message']})';
    } catch (_) {
      return '$fallback (${response.statusCode})';
    }
  }
}

class GithubAdminException implements Exception {
  const GithubAdminException(this.message);
  final String message;

  @override
  String toString() => message;
}
