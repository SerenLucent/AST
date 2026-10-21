import 'web_api.dart';
class GameScoreService {
  Future<void> save(String loginId, Map<String, dynamic> result) async {
    await WebApi.request({'action': 'gameScore', 'result': result});
  }
  void dispose() {}
}
