import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/game_score_service.dart';

class TimingShooterScreen extends StatefulWidget {
  const TimingShooterScreen({super.key, required this.loginId});
  final String loginId;
  @override
  State<TimingShooterScreen> createState() => _TimingShooterScreenState();
}

class _TimingShooterScreenState extends State<TimingShooterScreen> {
  static const gameUrl = String.fromEnvironment('AST_GAME_URL',
    defaultValue: 'https://serenlucent.github.io/AST/games/timing-shooter/');
  late final WebViewController _controller;
  final _scores = GameScoreService();
  final _savedRuns = <String>{};
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final allowed = Uri.parse(gameUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..addJavaScriptChannel('AstGameScores', onMessageReceived: _receiveScore)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          return uri != null && uri.scheme == 'https' && uri.host == allowed.host && uri.path.startsWith(allowed.path)
            ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
        onProgress: (value) { if (mounted) setState(() => _progress = value); },
        onPageStarted: (_) { if (mounted) setState(() => _error = null); },
        onWebResourceError: (error) {
          if (mounted && error.isForMainFrame == true) setState(() => _error = '게임을 불러오지 못했습니다.');
        },
      ))
      ..loadRequest(allowed);
  }

  Future<void> _receiveScore(JavaScriptMessage message) async {
    Map<String, dynamic> result;
    try { result = jsonDecode(message.message) as Map<String, dynamic>; }
    catch (_) { return; }
    final runId = result['runId'];
    if (result['type'] != 'stageClear' || result['game'] != 'timing-shooter' || runId is! String || runId.isEmpty || _savedRuns.contains(runId)) {
      return;
    }
    _savedRuns.add(runId);
    try {
      await _scores.save(widget.loginId, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('점수가 저장되었습니다.')));
      }
    } catch (_) {
      _savedRuns.remove(runId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('점수를 저장하지 못했습니다.'),
        action: SnackBarAction(label: '다시 저장', onPressed: () => _receiveScore(message)),
        ));
      }
    }
  }

  @override
  void dispose() {
    _controller.loadHtmlString('<html></html>');
    _scores.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('타이밍 슈터')),
    body: SafeArea(child: Stack(children: [
      WebViewWidget(controller: _controller),
      if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
      if (_error != null) Positioned.fill(child: ColoredBox(color: Colors.black,
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: Colors.white)),
          IconButton(onPressed: () => _controller.reload(), icon: const Icon(Icons.refresh, color: Colors.white), tooltip: '다시 불러오기'),
        ])),
      )),
    ])),
  );
}
