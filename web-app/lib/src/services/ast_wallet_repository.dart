import '../models/ast_wallet.dart';
import 'apps_script_gateway.dart';

abstract class AstWalletRepository {
  Future<AstWallet> fetch(String loginId);
  Future<AstClaimResult> claim(
    String loginId, {
    required String requestId,
    required int expectedAvailableAt,
  });
  void close() {}
}

class ServerAstWalletRepository extends AstWalletRepository {
  ServerAstWalletRepository({AppsScriptGateway? gateway})
    : _gateway = gateway ?? AppsScriptGateway();

  final AppsScriptGateway _gateway;

  @override
  Future<AstWallet> fetch(String loginId) async => AstWallet.fromResponse(
    await _gateway.fetchAstWallet(loginId.trim().toLowerCase()),
    loginId,
  );

  @override
  Future<AstClaimResult> claim(
    String loginId, {
    required String requestId,
    required int expectedAvailableAt,
  }) async {
    final response = await _gateway.claimAst(
      loginId.trim().toLowerCase(),
      requestId: requestId,
      expectedAvailableAt: expectedAvailableAt,
    );
    if (!{
      'claimed',
      'already_claimed',
      'waiting',
    }.contains(response['status'])) {
      throw const FormatException('Invalid AST claim response');
    }
    return AstClaimResult(
      AstWallet.fromResponse(response, loginId),
      credited: response['status'] == 'claimed',
    );
  }

  @override
  void close() => _gateway.close();
}
