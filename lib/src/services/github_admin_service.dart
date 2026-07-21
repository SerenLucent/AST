import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/score_file.dart';
import '../models/schedule_entry.dart';
import '../models/member_profile.dart';
import '../models/notice.dart';

class GithubAdminService {
  static const _owner = 'SerenLucent';
  static const _repository = 'AST';
  static const _branch = 'main';
  static const _tokenKey = 'github_admin_token';
  static String? _sessionToken;

  Future<String?> get token async {
    if (_sessionToken != null) return _sessionToken;
    final preferences = await SharedPreferences.getInstance();
    _sessionToken = preferences.getString(_tokenKey);
    return _sessionToken;
  }

  Future<void> saveToken(String value) async {
    _sessionToken = value.trim();
    final preferences = await SharedPreferences.getInstance();
    await preferences
        .setString(_tokenKey, _sessionToken!)
        .timeout(const Duration(seconds: 3));
  }

  Future<void> clearToken() async {
    _sessionToken = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }

  Future<bool> validateToken(String value) async {
    final response = await http
        .get(
          Uri.parse('https://api.github.com/repos/$_owner/$_repository'),
          headers: _headers(value.trim()),
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return false;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final permissions = body['permissions'] as Map<String, dynamic>?;
    return permissions?['push'] == true;
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

  Future<String> uploadMemberImage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (bytes.length > 10 * 1024 * 1024) {
      throw const GithubAdminException('10MB 이하의 이미지만 등록할 수 있습니다.');
    }
    final adminToken = await token;
    if (adminToken == null) {
      throw const GithubAdminException('GitHub 연결이 필요합니다.');
    }
    final response = await http.put(
      _contentsUri(['Image', fileName]),
      headers: _headers(adminToken),
      body: jsonEncode({
        'message': '팀원 사진 등록: $fileName',
        'content': base64Encode(bytes),
        'branch': _branch,
      }),
    );
    if (response.statusCode != 201) {
      throw GithubAdminException(_errorMessage(response, '사진을 등록하지 못했습니다.'));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final content = body['content'] as Map<String, dynamic>;
    return content['download_url'] as String;
  }

  Future<void> saveMembers(List<MemberProfile> members) async {
    final adminToken = await token;
    if (adminToken == null) {
      throw const GithubAdminException('GitHub 연결이 필요합니다.');
    }
    const segments = ['remote-data', 'members.json'];
    final current = await http.get(
      _contentsUri(segments),
      headers: _headers(adminToken),
    );
    String? sha;
    if (current.statusCode == 200) {
      sha =
          (jsonDecode(current.body) as Map<String, dynamic>)['sha'] as String?;
    } else if (current.statusCode != 404) {
      throw GithubAdminException(_errorMessage(current, '팀원 목록을 확인하지 못했습니다.'));
    }
    final source = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'members': members.map((member) => member.toJson()).toList(),
    });
    final response = await http.put(
      _contentsUri(segments),
      headers: _headers(adminToken),
      body: jsonEncode({
        'message': '팀원 소개 등록',
        'content': base64Encode(utf8.encode(source)),
        'branch': _branch,
        if (sha != null) 'sha': sha,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw GithubAdminException(_errorMessage(response, '팀원 소개를 저장하지 못했습니다.'));
    }
  }

  Future<void> saveNotices(List<Notice> notices) async {
    final adminToken = await token;
    if (adminToken == null) {
      throw const GithubAdminException('공지사항을 저장하려면 GitHub 연결이 필요합니다.');
    }
    const segments = ['remote-data', 'notices.json'];
    final current = await http.get(
      _contentsUri(segments),
      headers: _headers(adminToken),
    );
    String? sha;
    if (current.statusCode == 200) {
      sha =
          (jsonDecode(current.body) as Map<String, dynamic>)['sha'] as String?;
    } else if (current.statusCode != 404) {
      throw GithubAdminException(_errorMessage(current, '공지사항을 확인하지 못했습니다.'));
    }
    final source = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'notices': notices.map((notice) => notice.toJson()).toList(),
    });
    final response = await http.put(
      _contentsUri(segments),
      headers: _headers(adminToken),
      body: jsonEncode({
        'message': '공지사항 업데이트',
        'content': base64Encode(utf8.encode(source)),
        'branch': _branch,
        if (sha != null) 'sha': sha,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw GithubAdminException(_errorMessage(response, '공지사항을 저장하지 못했습니다.'));
    }
  }

  Future<void> saveBoardPosts(List<Notice> notices) async {
    final adminToken = await token;
    if (adminToken == null) {
      throw const GithubAdminException('게시물을 저장하려면 GitHub 연결이 필요합니다.');
    }
    const segments = ['remote-data', 'board.json'];
    final current = await http.get(
      _contentsUri(segments),
      headers: _headers(adminToken),
    );
    String? sha;
    if (current.statusCode == 200) {
      sha =
          (jsonDecode(current.body) as Map<String, dynamic>)['sha'] as String?;
    } else if (current.statusCode != 404) {
      throw GithubAdminException(_errorMessage(current, '게시판을 확인하지 못했습니다.'));
    }
    final source = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'notices': notices.map((notice) => notice.toJson()).toList(),
    });
    final response = await http.put(
      _contentsUri(segments),
      headers: _headers(adminToken),
      body: jsonEncode({
        'message': '게시판 업데이트',
        'content': base64Encode(utf8.encode(source)),
        'branch': _branch,
        if (sha != null) 'sha': sha,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw GithubAdminException(_errorMessage(response, '게시물을 저장하지 못했습니다.'));
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
