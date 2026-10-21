import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/ast_wallet.dart';
import 'ast_wallet_repository.dart';

/// The ticker is local; only refresh and explicit claims contact the server.
class AstWalletController extends ChangeNotifier {
  AstWalletController({
    required String loginId,
    required AstWalletRepository repository,
    Duration Function()? elapsed,
  }) : loginId = loginId.trim().toLowerCase(),
       _repository = repository {
    _watch.start();
    _elapsed = elapsed ?? (() => _watch.elapsed);
  }

  final String loginId;
  final AstWalletRepository _repository;
  final Stopwatch _watch = Stopwatch();
  late final Duration Function() _elapsed;
  Duration _anchor = Duration.zero;
  Timer? _timer;
  bool _disposed = false;
  bool _active = true;
  String? _requestId;
  int? _requestCycle;
  AstWallet? wallet;
  bool loading = false;
  bool claiming = false;
  String? error;

  int get remainingSeconds {
    final current = wallet;
    if (current == null) return AstWallet.interval.inSeconds;
    final elapsed = (_elapsed() - _anchor).inMilliseconds;
    final remaining = current.availableAt - current.serverNow - max(0, elapsed);
    return (remaining / 1000).ceil().clamp(0, AstWallet.interval.inSeconds);
  }

  double get progress =>
      wallet == null
          ? 0
          : (1 - remainingSeconds / AstWallet.interval.inSeconds).clamp(0, 1);
  bool get ready => wallet != null && remainingSeconds == 0;

  Future<void> refresh() async {
    if (_disposed || loading || claiming) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repository.fetch(loginId);
      if (_disposed) return;
      _apply(result);
    } catch (_) {
      if (_disposed) return;
      error = '아스트 서버에 연결하지 못했어요. 다시 시도해 주세요.';
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> claim() async {
    if (_disposed || !ready || claiming || loading) return false;
    claiming = true;
    error = null;
    final cycle = wallet!.availableAt;
    // Keep the same request after an ambiguous timeout. The cycle additionally
    // prevents an old retry from claiming a later hour on another device.
    if (_requestCycle != cycle) {
      final random = Random.secure();
      _requestId =
          List.generate(
            16,
            (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
      _requestCycle = cycle;
    }
    notifyListeners();
    try {
      final result = await _repository.claim(
        loginId,
        requestId: _requestId!,
        expectedAvailableAt: cycle,
      );
      if (_disposed) return false;
      _apply(result.wallet);
      return result.credited;
    } catch (_) {
      if (!_disposed) {
        error = '수령 결과를 확인하지 못했어요. 다시 눌러도 중복 지급되지 않아요.';
      }
      return false;
    } finally {
      if (!_disposed) {
        claiming = false;
        notifyListeners();
      }
    }
  }

  void _apply(AstWallet value) {
    if (value.loginId != loginId) {
      throw const FormatException('AST wallet account mismatch');
    }
    wallet = value;
    _anchor = _elapsed();
    _startTicker();
  }

  void _startTicker() {
    _timer?.cancel();
    if (!_active || wallet == null || ready) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      notifyListeners();
      if (ready) _timer?.cancel();
    });
  }

  void setActive(bool active) {
    _active = active;
    if (active) {
      _startTicker();
      unawaited(refresh());
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watch.stop();
    super.dispose();
  }
}
