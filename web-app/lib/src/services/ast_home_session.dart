import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'apps_script_gateway.dart';

/// Binds one WebView to one account. This is retry isolation, not authentication.
class AstHomeSession {
  AstHomeSession({required String loginId, required AppsScriptGateway gateway})
    : loginId = loginId.trim().toLowerCase(),
      _gateway = gateway;

  final String loginId;
  final AppsScriptGateway _gateway;
  late final String accountKey =
      sha256.convert(utf8.encode(loginId)).toString();

  bool matchesAccount(String value) => value.trim().toLowerCase() == loginId;

  Future<Map<String, dynamic>> request(Map<String, dynamic> payload) async {
    final action = payload['action'];
    if (loginId.isEmpty ||
        (action != 'astHomeGet' && action != 'astHomeApply')) {
      throw const FormatException('올바른 집 꾸미기 요청이 아닙니다.');
    }
    // A write without an owner (including legacy unscoped retries) is unsafe.
    if ((action == 'astHomeApply' || payload.containsKey('accountKey')) &&
        payload['accountKey'] != accountKey) {
      throw const FormatException('구매 계정이 다릅니다. 집 꾸미기에 다시 입장해 주세요.');
    }
    final result = await _gateway.homeRequest({...payload, 'loginId': loginId});
    return {...result, 'accountKey': accountKey};
  }
}
