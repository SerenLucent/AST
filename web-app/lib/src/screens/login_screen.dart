import 'package:flutter/material.dart';

import '../widgets/brand_header.dart';
import 'package:nwc_player_lab/main.dart' show Lab;

typedef LoginCallback = Future<bool> Function(String id, String password);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});

  final LoginCallback onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });
    try {
    final success = await widget.onLogin(
      _idController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디 또는 팀 공용 비밀번호를 확인해주세요.')),
      );
    }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally { if (mounted) setState(() => _submitting = false); }
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandHeader(
                      title: '우리의 목소리를 한곳에',
                      subtitle: 'AST 웹 · iPhone에서도 함께\n기존 아이디와 팀 공용 비밀번호로 로그인하세요.',
                    ),
                    const SizedBox(height: 44),
                    TextFormField(
                      controller: _idController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '아이디',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator:
                          (value) =>
                              value == null || value.trim().length < 2
                                  ? '두 글자 이상의 아이디를 입력해주세요.'
                                  : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: '팀 공용 비밀번호',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed:
                              () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? '비밀번호를 입력해주세요.'
                                  : null,
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child:
                          _submitting
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('로그인'),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '로그인 유지: 마지막 사용 후 30일\n홈 화면에 추가한 AST 아이콘에서 로그인하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF777184), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Lab(embedded: true, soundfontAsset: 'packages/nwc_player_lab/assets/soundfonts/piano.sf2'))),
                      icon: const Icon(Icons.music_note_outlined), label: const Text('NWC 플레이어 먼저 사용하기'),
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
