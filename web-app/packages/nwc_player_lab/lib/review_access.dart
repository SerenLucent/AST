import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'player_localizations.dart';

const reviewOfflineGrace = Duration(days: 7);
const _reviewCodeKey = 'nwc_review_access_code_v1';
final _codePattern = RegExp(r'^NWC-REVIEW-[A-F0-9]{32}$');

/// Reviewer access uses the real Pro controls, but never creates a Play purchase.
/// Only the code is stored securely; each cold start requires server validation.
class ReviewAccess extends ChangeNotifier {
  ReviewAccess({
    required http.Client client,
    required FlutterSecureStorage secureStorage,
    required this.verificationUrl,
    required DateTime Function() now,
  }) : _client = client,
       _storage = secureStorage,
       _now = now;

  // Owned by ProAccess, not by this controller.
  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String verificationUrl;
  final DateTime Function() _now;
  final _leaseWatch = Stopwatch();
  Timer? _expiryTimer;
  DateTime? _verifiedAt, _lastSeenAt, _lastAttempt;
  String? _code;
  bool _disposed = false, _initialized = false;
  bool _unlocked = false;
  bool get unlocked => _unlocked;
  bool get hasCode => _code != null;
  bool busy = false;
  LocalizedText? message;

  Uri? get endpoint {
    final uri = Uri.tryParse(verificationUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.resolve('/review-access');
  }

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    busy = true;
    notifyListeners();
    try {
      final stored = await _storage.read(key: _reviewCodeKey);
      if (_disposed) return;
      if (stored != null && _codePattern.hasMatch(stored)) _code = stored;
    } catch (_) {
      // Storage failure must not grant access or affect a genuine purchase.
    } finally {
      busy = false;
      notifyListeners();
    }
    if (!_disposed) await refresh();
  }

  Future<bool> activate(String input) async {
    if (_disposed || busy) return false;
    final code = input.trim().toUpperCase();
    if (!_codePattern.hasMatch(code)) {
      message = (s) => s.reviewInvalid;
      notifyListeners();
      return false;
    }
    final uri = endpoint;
    if (uri == null) {
      message = (s) => s.reviewUnavailable;
      notifyListeners();
      return false;
    }
    busy = true;
    message = null;
    _lastAttempt = _now().toUtc();
    notifyListeners();
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'packageName': 'com.lucentylabs.nwcplayer',
              'productId': 'nwc_player_pro_unlock',
              'source': 'review_code',
              'reviewCode': code,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (_disposed) return false;
      if (response.statusCode != 200) throw const FormatException();
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> ||
          body['active'] is! bool ||
          body['productId'] != 'nwc_player_pro_unlock' ||
          body['grant'] != 'review') {
        throw const FormatException();
      }
      if (body['active'] != true) {
        // A typo while replacing a code must not remove an existing valid one.
        if (_code == code) await _clear();
        message = (s) => s.reviewInvalid;
        return false;
      }
      _code = code;
      _verifiedAt = _lastSeenAt = _now().toUtc();
      _unlocked = true;
      _leaseWatch
        ..reset()
        ..start();
      _expiryTimer?.cancel();
      _expiryTimer = Timer(
        reviewOfflineGrace + const Duration(milliseconds: 1),
        checkExpiry,
      );
      message = (s) => s.reviewActive;
      try {
        await _storage.write(key: _reviewCodeKey, value: code);
      } catch (_) {
        // This session works; re-enter the code if storage is unavailable.
      }
      return !_disposed;
    } catch (_) {
      if (!_disposed) {
        checkExpiry();
        message = (s) => s.reviewUnavailable;
      }
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    checkExpiry();
    final code = _code;
    if (!_disposed && code != null && !busy) await activate(code);
  }

  void tick() {
    checkExpiry();
    if (_code != null &&
        (_lastAttempt == null ||
            _now().toUtc().difference(_lastAttempt!) >=
                const Duration(hours: 1))) {
      unawaited(refresh());
    }
  }

  void checkExpiry() {
    if (_disposed) return;
    final now = _now().toUtc();
    final rolledBack = _lastSeenAt != null && now.isBefore(_lastSeenAt!);
    if (_unlocked &&
        (rolledBack ||
            _verifiedAt == null ||
            now.difference(_verifiedAt!) > reviewOfflineGrace ||
            _leaseWatch.elapsed > reviewOfflineGrace)) {
      _unlocked = false;
      message = (s) => s.reviewReconnect;
      notifyListeners();
    }
    if (!rolledBack) _lastSeenAt = now;
  }

  Future<void> clear() async {
    if (_disposed || busy) return;
    busy = true;
    await _clear();
    message = null;
    busy = false;
    notifyListeners();
  }

  Future<void> _clear() async {
    _unlocked = false;
    _code = null;
    _verifiedAt = _lastSeenAt = _lastAttempt = null;
    _expiryTimer?.cancel();
    _leaseWatch.stop();
    // Notify before slow storage work so revoked controls lock immediately.
    notifyListeners();
    try {
      await _storage.delete(key: _reviewCodeKey);
    } catch (_) {}
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiryTimer?.cancel();
    _leaseWatch.stop();
    super.dispose();
  }
}
