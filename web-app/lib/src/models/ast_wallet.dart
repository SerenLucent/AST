/// An authoritative, account-scoped snapshot returned by the AST server.
class AstWallet {
  const AstWallet({
    required this.loginId,
    required this.balance,
    required this.cycleStartedAt,
    required this.availableAt,
    required this.serverNow,
    this.lastClaimedAt,
  });

  static const reward = 10;
  static const interval = Duration(hours: 1);
  final String loginId;
  final int balance;
  final int cycleStartedAt;
  final int availableAt;
  final int serverNow;
  final int? lastClaimedAt;

  factory AstWallet.fromResponse(
    Map<String, dynamic> response,
    String loginId,
  ) {
    final data = response['wallet'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing AST wallet');
    }
    int integer(Object? value) {
      if (value is! int || value < 0 || value > 9007199254740991) {
        throw const FormatException('Invalid AST wallet number');
      }
      return value;
    }

    final id = loginId.trim().toLowerCase();
    final balance = integer(data['balance']);
    final started = integer(data['cycleStartedAt']);
    final available = integer(data['availableAt']);
    final now = integer(response['serverNow']);
    final last =
        data['lastClaimedAt'] == null ? null : integer(data['lastClaimedAt']);
    if (data['loginId'] != id ||
        data['schemaVersion'] != 1 ||
        response['reward'] != reward ||
        response['intervalSeconds'] != interval.inSeconds ||
        available - started != interval.inMilliseconds ||
        (last != null && last != started)) {
      throw const FormatException('Inconsistent AST wallet');
    }
    return AstWallet(
      loginId: id,
      balance: balance,
      cycleStartedAt: started,
      availableAt: available,
      serverNow: now,
      lastClaimedAt: last,
    );
  }
}

class AstClaimResult {
  const AstClaimResult(this.wallet, {required this.credited});
  final AstWallet wallet;
  final bool credited;
}
