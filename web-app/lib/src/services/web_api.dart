import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WebApi {
  static const tokenKey = 'ast_web_v1_session';
  static const expiryKey = 'ast_web_v1_expires';
  static String? _endpoint;
  static Future<String> endpoint() async {
    if (_endpoint != null) return _endpoint!;
    final r = await http.get(Uri.base.resolve('web-config.json')).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw const WebApiException('웹 연결 설정을 불러오지 못했습니다.');
    final value = (jsonDecode(r.body) as Map)['apiUrl']?.toString() ?? '';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host != 'script.google.com' ||
        !uri.path.startsWith('/macros/s/') || !uri.path.endsWith('/exec')) {
      throw const WebApiException('웹 로그인 서버 연결 준비 중입니다. 아래 버튼으로 NWC 플레이어를 먼저 사용할 수 있습니다.', code: 'SETUP_REQUIRED');
    }
    return _endpoint = value;
  }
  static Future<Map<String, dynamic>> request(Map<String, dynamic> payload,
      {bool authenticated = true, Duration timeout = const Duration(seconds: 90)}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    if (authenticated && (token == null || token.isEmpty)) {
      throw const WebApiException('로그인이 필요합니다.', code: 'UNAUTHORIZED');
    }
    // Simple POST: no custom headers/preflight and automatic browser redirects.
    final r = await http.post(Uri.parse(await endpoint()),
      headers: const {'Content-Type': 'text/plain;charset=UTF-8'},
      body: jsonEncode({...payload, if (authenticated) 'sessionToken': token}),
    ).timeout(timeout);
    Map<String, dynamic> body;
    try { body = jsonDecode(r.body) as Map<String, dynamic>; }
    catch (_) { throw const WebApiException('서버 응답을 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.'); }
    if (r.statusCode != 200 || body['ok'] != true) {
      if (body['code'] == 'UNAUTHORIZED') {
        await prefs.remove(tokenKey); await prefs.remove(expiryKey);
      }
      throw WebApiException(body['error']?.toString() ?? '요청하지 못했습니다.', code: body['code']?.toString());
    }
    if (body['expiresAt'] is num) await prefs.setInt(expiryKey, (body['expiresAt'] as num).toInt());
    return body;
  }
}
class WebApiException implements Exception {
  const WebApiException(this.message, {this.code});
  final String message; final String? code;
  @override String toString() => message;
}
