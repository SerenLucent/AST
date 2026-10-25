import 'web_api.dart';

class WebAccessAuthRequired implements Exception {
  const WebAccessAuthRequired();
}

class WebAccessException implements Exception {
  const WebAccessException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WebAccessRepository {
  // The web administrator already has a verified, server-owned session.
  Future<Map<String, DateTime>> fetch() async {
    final body = await WebApi.request({'action': 'adminWebAccess'});
    return decodeWebAccess(body);
  }

  Future<void> authenticate(String loginId, String password) async {
    throw const WebAccessException('웹 관리자 계정으로 다시 로그인해 주세요.');
  }

  void close() {}
}

Map<String, DateTime> decodeWebAccess(Map<String, dynamic> body) {
  final source = body['webAccess'];
  if (source is! Map) {
    throw const WebAccessException('웹용 Apps Script를 최신 코드로 재배포해 주세요.');
  }
  final dates = <String, DateTime>{};
  for (final entry in source.entries) {
    final value = entry.value;
    if (entry.key is! String ||
        value is! int ||
        value <= 0 ||
        value > 8640000000000000) {
      throw const WebAccessException('올바르지 않은 웹 접속 기록입니다.');
    }
    dates[(entry.key as String).trim().toLowerCase()] =
        DateTime.fromMillisecondsSinceEpoch(value).toLocal();
  }
  return dates;
}
