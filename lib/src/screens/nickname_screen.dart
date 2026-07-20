import 'package:flutter/material.dart';

import '../widgets/brand_header.dart';

class NicknameScreen extends StatefulWidget {
  const NicknameScreen({
    super.key,
    required this.loginId,
    required this.onSave,
  });

  final String loginId;
  final Future<void> Function(String nickname) onSave;

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.text.trim().length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('본명을 두 글자 이상 입력해주세요.')));
      return;
    }
    setState(() => _saving = true);
    await widget.onSave(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BrandHeader(
                    title: '${widget.loginId}님, 반가워요!',
                    subtitle: '게시글과 일정에서 서로 알아볼 수 있도록\n사용할 본명을 등록해주세요.',
                  ),
                  const SizedBox(height: 44),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      labelText: '본명',
                      hintText: '예: 홍길동',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '등록 중...' : '확인하고 시작하기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
