import 'package:flutter/material.dart';
import '../widgets/browser_game.dart';
import '../services/game_score_service.dart';
class TimingShooterScreen extends StatelessWidget {
  const TimingShooterScreen({super.key, required this.loginId});
  final String loginId;
  @override Widget build(BuildContext context) => BrowserGame(kind: 'timing-shooter', title: '타이밍 슈터', onRequest: (payload) async {
    await GameScoreService().save(loginId, payload);
    return {'ok': true};
  });
}
