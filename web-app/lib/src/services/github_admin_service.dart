import 'dart:convert';
import 'dart:typed_data';

import '../models/score_file.dart';
import '../models/schedule_entry.dart';
import '../models/member_profile.dart';
import '../models/notice.dart';
import '../models/team_user.dart';
import 'apps_script_gateway.dart';

class GithubAdminService {
  GithubAdminService({AppsScriptGateway? gateway})
    : _gateway = gateway ?? AppsScriptGateway();

  final AppsScriptGateway _gateway;

  Future<String?> get token async {
    return null;
  }

  Future<void> saveToken(String value) async {
    throw const GithubAdminException('웹에는 GitHub 관리자 키를 저장하지 않습니다.');
  }

  Future<void> clearToken() async {
  }

  Future<bool> validateToken(String value) async {
    return false;
  }

  Future<void> uploadPdf({
    required String fileName,
    required Uint8List bytes,
    String? existingSha,
  }) async {
    if (bytes.length > 30 * 1024 * 1024) {
      throw const GithubAdminException('30MB 이하의 PDF만 업로드할 수 있습니다.');
    }
    await _uploadViaGateway(
      folder: 'Music',
      fileName: fileName,
      bytes: bytes,
      message: '악보 업로드: $fileName',
      existingSha: existingSha,
    );
  }

  Future<void> uploadHistoryFile({
    required String fileName,
    required Uint8List bytes,
    String? existingSha,
  }) => _uploadViaGateway(
    folder: 'Doc',
    fileName: fileName,
    bytes: bytes,
    existingSha: existingSha,
    message: '행사 히스토리 업로드: $fileName',
  );

  Future<void> saveSchedules(List<ScheduleEntry> schedules) async {
    await _saveJson(
      path: 'remote-data/schedule.json',
      message: '일정 업데이트',
      content: {
        'schemaVersion': 1,
        'schedules': schedules.map((entry) => entry.toJson()).toList(),
      },
    );
  }

  Future<String> uploadMemberImage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (bytes.length > 8 * 1024 * 1024) {
      throw const GithubAdminException('8MB 이하의 이미지만 등록할 수 있습니다.');
    }
    return _uploadViaGateway(
      folder: 'Image',
      fileName: fileName,
      bytes: bytes,
      message: '팀원 사진 등록: $fileName',
    );
  }

  Future<void> saveMembers(List<MemberProfile> members) async {
    await _saveJson(
      path: 'remote-data/members.json',
      message: '팀원 소개 등록',
      content: {
        'schemaVersion': 1,
        'members': members.map((member) => member.toJson()).toList(),
      },
    );
  }

  Future<void> saveNotices(List<Notice> notices) async {
    await _saveJson(
      path: 'remote-data/notices.json',
      message: '공지사항 업데이트',
      content: {
        'schemaVersion': 1,
        'notices': notices.map((notice) => notice.toJson()).toList(),
      },
    );
  }

  Future<void> saveBoardPosts(List<Notice> notices) async {
    await _saveJson(
      path: 'remote-data/board.json',
      message: '게시판 업데이트',
      content: {
        'schemaVersion': 1,
        'notices': notices.map((notice) => notice.toJson()).toList(),
      },
    );
  }

  Future<void> saveUsers(List<TeamUser> users) async {
    await _saveJson(
      path: 'remote-data/users.json',
      message: '사용자 및 권한 업데이트',
      content: {
        'schemaVersion': 1,
        'users': users.map((user) => user.toJson()).toList(),
      },
    );
  }

  Future<void> saveGenerations(Map<String, List<String>> generations) async {
    final normalized = {
      for (final entry in generations.entries)
        entry.key.toLowerCase(): TeamUser.sortGenerations(entry.value),
    };
    await _saveJson(
      path: 'remote-data/generations.json',
      message: '기수 정보 업데이트',
      content: {'schemaVersion': 1, 'generations': normalized},
    );
  }

  Future<void> _saveJson({
    required String path,
    required String message,
    required Object content,
  }) async {
    try {
      await _gateway.saveJson(path: path, content: content, message: message);
    } on AppsScriptGatewayException catch (error) {
      throw GithubAdminException(error.message);
    }
  }

  Future<String> _uploadViaGateway({
    required String folder,
    required String fileName,
    required Uint8List bytes,
    required String message,
    String? existingSha,
  }) async {
    if (bytes.length > 30 * 1024 * 1024) {
      throw const GithubAdminException('30MB 이하의 파일만 업로드할 수 있습니다.');
    }
    try {
      return await _gateway.uploadFile(
        folder: folder,
        fileName: fileName,
        bytes: bytes,
        message: message,
        existingSha: existingSha,
      );
    } on AppsScriptGatewayException catch (error) {
      throw GithubAdminException(error.message);
    }
  }

  Future<void> deleteScore(ScoreFile score) async {
    try {
      await _gateway.deleteFile(
        path: score.path,
        sha: score.sha,
        message: '악보 삭제: ${score.name}',
      );
    } on AppsScriptGatewayException catch (error) {
      throw GithubAdminException(error.message);
    }
  }

  Map<String, String> _headers(String value) => {
    'Accept': 'application/vnd.github+json',
    'Authorization': 'Bearer $value',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json',
  };
}

class GithubAdminException implements Exception {
  const GithubAdminException(this.message);
  final String message;

  @override
  String toString() => message;
}
