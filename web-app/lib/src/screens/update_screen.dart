import 'dart:html' as html;
import 'package:flutter/material.dart';
class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AST 웹버전')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('아이폰에서도, 우리의 목소리를 한곳에', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      const Text('Safari에서 공유 → 홈 화면에 추가를 선택하세요. 추가된 AST 아이콘에서 로그인하면 다음에도 로그인 상태가 유지됩니다.\n\n웹버전은 APK를 설치하지 않습니다. 업데이트는 새로고침으로 받을 수 있습니다.\n\nNWC 재생은 재생 버튼을 눌러 시작하세요. 화면 잠금·다른 앱 전환 시 브라우저가 재생을 중단할 수 있습니다.'),
      const SizedBox(height: 24),
      FilledButton.icon(onPressed: () => html.window.location.reload(), icon: const Icon(Icons.refresh), label: const Text('웹버전 새로고침')),
    ]),
  );
}
