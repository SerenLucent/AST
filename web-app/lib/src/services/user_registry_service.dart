import 'web_api.dart';

class UserRegistryService {
  bool _sending = false;
  DateTime? _lastSent;

  // Session-owned identity and server time only. No GitHub users.json rewrite,
  // no background periodic heartbeat. Login/restore already record server-side.
  Future<void> recordLogin({required String loginId, String? nickname}) async {
    final now = DateTime.now();
    if (_sending ||
        (_lastSent != null &&
            now.difference(_lastSent!) < const Duration(minutes: 1))) {
      return;
    }
    _sending = true;
    try {
      await WebApi.request({
        'action': 'webAccess',
      }, timeout: const Duration(seconds: 20));
      _lastSent = now;
    } finally {
      _sending = false;
    }
  }

  // Authenticated profile endpoint already owns nickname changes.
  Future<void> updateNickname({
    required String loginId,
    required String nickname,
  }) async {}
}
