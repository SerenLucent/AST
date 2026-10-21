import 'package:flutter/material.dart';
import '../widgets/browser_game.dart';
import '../services/apps_script_gateway.dart';
import '../services/ast_home_session.dart';
import '../services/user_repository.dart';
class AstHomeScreen extends StatefulWidget {
  const AstHomeScreen({super.key, required this.loginId});
  final String loginId;
  @override State<AstHomeScreen> createState() => _AstHomeScreenState();
}
class _AstHomeScreenState extends State<AstHomeScreen> {
  late final session = AstHomeSession(loginId: widget.loginId, gateway: AppsScriptGateway());
  @override Widget build(BuildContext context) => BrowserGame(kind: 'ast-home', title: 'AST 집 꾸미기', onRequest: (payload) async {
    final result = await session.request(payload);
    try {
      final users = await UserRepository().fetch();
      result['memberNames'] = {for (final u in users) u.loginId.toLowerCase(): u.nickname};
    } catch (_) {}
    return result;
  });
}
