import 'dart:convert';
import 'web_api.dart';

class AppsScriptGateway {
  bool get isConfigured => true;
  Future<Map<String, dynamic>> fetchAstWallet(String loginId) => _post({'action': 'astWalletGet'});
  Future<Map<String, dynamic>> claimAst(String loginId, {required String requestId, required int expectedAvailableAt}) =>
      _post({'action': 'astWalletClaim', 'requestId': requestId, 'expectedAvailableAt': expectedAvailableAt});
  Future<Map<String, dynamic>> homeRequest(Map<String, dynamic> payload) => _post(payload);
  Future<void> saveJson({required String path, required Object content, required String message}) async {
    await _post({'action': 'saveJson', 'path': path, 'content': content, 'message': message});
  }
  Future<String> uploadFile({required String folder, required String fileName, required List<int> bytes,
      required String message, String? existingSha}) async {
    final r = await _post({'action': 'upload', 'folder': folder, 'fileName': fileName,
      'contentBase64': base64Encode(bytes), 'message': message, if (existingSha != null) 'existingSha': existingSha});
    return r['downloadUrl']?.toString() ?? '';
  }
  Future<void> deleteFile({required String path, required String sha, required String message}) async {
    await _post({'action': 'delete', 'path': path, 'sha': sha, 'message': message});
  }
  Future<Map<String, dynamic>> _post(Map<String, dynamic> payload) async {
    try { return await WebApi.request({'action': 'proxy', 'payload': payload}); }
    on WebApiException catch (e) { throw AppsScriptGatewayException(e.message); }
  }
  void close() {}
}
class AppsScriptGatewayException implements Exception {
  const AppsScriptGatewayException(this.message);
  final String message;
  @override String toString() => message;
}
