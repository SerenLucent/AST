import 'package:flutter/material.dart';

import '../widgets/brand_header.dart';

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

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
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
                      subtitle: 'AST 아카펠라 팀 전용 공간입니다.\n공지받은 공용 비밀번호로 입장해주세요.',
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
                      '처음 사용하는 아이디라면 다음 화면에서 본명을 등록합니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF777184), fontSize: 13),
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
