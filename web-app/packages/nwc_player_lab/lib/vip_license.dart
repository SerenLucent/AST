import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const nwcLicenseWebAppUrl =
    'https://script.google.com/macros/s/AKfycbwsHcem06vVefV4LOT5f33zDBN_vuRlY9TF1FRzyu4fSWEXgbUqnQg_gdRRAYqRiHlsdw/exec';

class VipLicenseResult {
  const VipLicenseResult({
    required this.licensedTo,
    required this.validUntil,
    required this.serverTime,
  });

  final String licensedTo;
  final DateTime validUntil;
  final DateTime serverTime;
}

class VipLicenseClient {
  VipLicenseClient({http.Client? client, String? webAppUrl})
    : _client = client ?? http.Client(),
      webAppUrl = webAppUrl ?? nwcLicenseWebAppUrl;

  final http.Client _client;
  final String webAppUrl;

  Future<VipLicenseResult> activate({
    required String licenseKey,
    required String installationId,
  }) => _request('activate', licenseKey, installationId);

  Future<VipLicenseResult> validate({
    required String licenseKey,
    required String installationId,
  }) => _request('validate', licenseKey, installationId);

  Future<VipLicenseResult> _request(
    String action,
    String licenseKey,
    String installationId,
  ) async {
    final request =
        http.Request('POST', Uri.parse(webAppUrl))
          ..followRedirects = false
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({
            'action': action,
            'licenseKey': licenseKey.trim(),
            'installationId': installationId,
          });
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 25));
    var response = await http.Response.fromStream(streamed);
    if (_isRedirect(response.statusCode)) {
      final location = response.headers['location'];
      if (location == null || location.isEmpty) {
        throw const VipLicenseException('라이선스 서버 응답을 확인하지 못했습니다.');
      }
      response = await _client
          .get(Uri.parse(webAppUrl).resolve(location))
          .timeout(const Duration(seconds: 25));
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const VipLicenseException('라이선스 서버 응답을 읽지 못했습니다.');
    }
    if (response.statusCode != 200 || body['ok'] != true) {
      throw VipLicenseException(
        body['error']?.toString() ?? '라이선스 인증에 실패했습니다.',
      );
    }
    final validUntil = DateTime.tryParse(body['validUntil']?.toString() ?? '');
    final serverTime = DateTime.tryParse(body['serverTime']?.toString() ?? '');
    if (validUntil == null || serverTime == null) {
      throw const VipLicenseException('라이선스 유효기간을 확인하지 못했습니다.');
    }
    return VipLicenseResult(
      licensedTo: body['licensedTo']?.toString() ?? '',
      validUntil: validUntil.toUtc(),
      serverTime: serverTime.toUtc(),
    );
  }

  bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;
}

class VipLicenseStore {
  VipLicenseStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _installationIdKey = 'vip_installation_id';
  static const _licenseKey = 'vip_license_key';
  static const _validUntilKey = 'vip_valid_until';
  static const _serverTimeKey = 'vip_server_time';
  static const _lastLocalTimeKey = 'vip_last_local_time';
  static const _licensedToKey = 'vip_licensed_to';

  final FlutterSecureStorage _storage;

  Future<String> installationId() async {
    final saved = await _storage.read(key: _installationIdKey);
    if (saved != null && saved.length >= 16) return saved;
    final random = Random.secure();
    final generated = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    await _storage.write(key: _installationIdKey, value: generated);
    return generated;
  }

  Future<String?> get licenseKey => _storage.read(key: _licenseKey);
  Future<String?> get licensedTo => _storage.read(key: _licensedToKey);

  Future<DateTime?> readDate(String key) async {
    final value = await _storage.read(key: key);
    return value == null ? null : DateTime.tryParse(value)?.toUtc();
  }

  Future<DateTime?> get validUntil => readDate(_validUntilKey);
  Future<DateTime?> get serverTime => readDate(_serverTimeKey);
  Future<DateTime?> get lastLocalTime => readDate(_lastLocalTimeKey);

  Future<void> noteLocalTime(DateTime value) => _storage.write(
    key: _lastLocalTimeKey,
    value: value.toUtc().toIso8601String(),
  );

  Future<void> saveResult(String key, VipLicenseResult result) async {
    await _storage.write(key: _licenseKey, value: key.trim());
    await _storage.write(
      key: _validUntilKey,
      value: result.validUntil.toIso8601String(),
    );
    await _storage.write(
      key: _serverTimeKey,
      value: result.serverTime.toIso8601String(),
    );
    await _storage.write(key: _licensedToKey, value: result.licensedTo);
    await noteLocalTime(DateTime.now().toUtc());
  }

  Future<void> clearLicense() async {
    for (final key in [
      _licenseKey,
      _validUntilKey,
      _serverTimeKey,
      _lastLocalTimeKey,
      _licensedToKey,
    ]) {
      await _storage.delete(key: key);
    }
  }
}

class VipLicenseGate extends StatefulWidget {
  const VipLicenseGate({super.key, required this.builder});

  final Widget Function(String licensedTo) builder;

  @override
  State<VipLicenseGate> createState() => _VipLicenseGateState();
}

class _VipLicenseGateState extends State<VipLicenseGate> {
  final _client = VipLicenseClient();
  final _store = VipLicenseStore();
  final _controller = TextEditingController();
  bool _checking = true;
  bool _submitting = false;
  String? _licensedTo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final now = DateTime.now().toUtc();
    try {
      final key = await _store.licenseKey;
      final validUntil = await _store.validUntil;
      final lastLocal = await _store.lastLocalTime;
      final name = await _store.licensedTo;
      final clockRolledBack =
          lastLocal != null &&
          now.isBefore(lastLocal.subtract(const Duration(minutes: 5)));
      await _store.noteLocalTime(now);
      if (key == null || key.isEmpty) return;
      _controller.text = key;
      if (!clockRolledBack && validUntil != null && now.isBefore(validUntil)) {
        _licensedTo = name ?? '';
        return;
      }
      final result = await _client.validate(
        licenseKey: key,
        installationId: await _store.installationId(),
      );
      await _store.saveResult(key, result);
      _licensedTo = result.licensedTo;
    } on VipLicenseException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = '인터넷 연결 후 라이선스를 다시 확인해주세요.';
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _activate() async {
    final key = _controller.text.trim();
    if (key.length < 16) {
      setState(() => _error = '발급받은 VIP 라이선스 번호를 입력해주세요.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await _client.activate(
        licenseKey: key,
        installationId: await _store.installationId(),
      );
      await _store.saveResult(key, result);
      if (mounted) setState(() => _licensedTo = result.licensedTo);
    } on VipLicenseException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '라이선스 서버에 연결하지 못했습니다.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('VIP 라이선스를 확인하고 있습니다.'),
            ],
          ),
        ),
      );
    }
    if (_licensedTo != null) return widget.builder(_licensedTo!);
    return Scaffold(
      appBar: AppBar(title: const Text('NWC Player VIP')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      size: 58,
                      color: Color(0xff7257a8),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'VIP 라이선스 등록',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '발급받은 인증번호를 입력하면 이 기기에 등록됩니다.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _controller,
                      enabled: !_submitting,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'VIP 라이선스 번호',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _activate(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _activate,
                      icon:
                          _submitting
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.verified_user),
                      label: Text(_submitting ? '인증 중' : '이 기기에 등록'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VipLicenseException implements Exception {
  const VipLicenseException(this.message);
  final String message;
}
