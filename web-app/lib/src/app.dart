import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/nickname_screen.dart';
import 'services/session_service.dart';
import 'services/user_registry_service.dart';
import 'theme/app_theme.dart';

Widget fixedAppTextScale(BuildContext context, Widget? child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
  child: child ?? const SizedBox.shrink(),
);

class AstTeamApp extends StatefulWidget {
  const AstTeamApp({super.key, this.sessionService});

  final SessionService? sessionService;

  @override
  State<AstTeamApp> createState() => _AstTeamAppState();
}

class _AstTeamAppState extends State<AstTeamApp> {
  late final SessionService _session;
  final UserRegistryService _registry = UserRegistryService();
  bool _loading = true;
  bool _showTitle = true;
  String? _loginId;
  String? _nickname;
  String? _role;
  String? _restoreError;

  @override
  void initState() {
    super.initState();
    _session = widget.sessionService ?? SessionService();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    setState(() { _loading = true; _restoreError = null; });
    try {
    final profile = await _session.currentProfile();
    if (!mounted) return;
    setState(() {
      _loginId = profile?.loginId;
      _nickname = profile?.nickname;
      _role = profile?.role;
      _loading = false;
    });
    if (profile != null) {
      unawaited(
        _registry
            .recordLogin(loginId: profile.loginId, nickname: profile.nickname)
            .timeout(const Duration(seconds: 10))
            .catchError((_) {}),
      );
    }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _restoreError = '로그인 상태를 확인하지 못했습니다. 인터넷 연결 후 다시 시도해 주세요.'; });
    }
  }

  Future<bool> _login(String id, String password) async {
    if (!await _session.canSignIn(id, password)) return false;
    final profile = await _session.signIn(id);
    try {
      await _registry
          .recordLogin(loginId: profile.loginId, nickname: profile.nickname)
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      // A temporary GitHub write failure must not prevent local sign-in.
    }
    if (!mounted) return true;
    setState(() {
      _loginId = profile.loginId;
      _nickname = profile.nickname;
      _role = profile.role;
    });
    return true;
  }

  Future<void> _saveNickname(String nickname) async {
    final profile = await _session.registerNickname(_loginId!, nickname);
    if (!mounted) return;
    setState(() {
      _nickname = profile.nickname;
      _role = profile.role;
    });
    unawaited(
      _registry
          .updateNickname(loginId: profile.loginId, nickname: profile.nickname!)
          .timeout(const Duration(seconds: 25))
          .catchError((_) {}),
    );
  }

  Future<void> _logout() async {
    setState(() {
      _loginId = null;
      _nickname = null;
      _role = null;
    });
    await _session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AST 아카펠라',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: fixedAppTextScale,
      home:
          _showTitle
              ? _SplashScreen(onTap: () => setState(() => _showTitle = false))
              : _loading
              ? const _LoadingScreen()
              : _restoreError != null
              ? Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(padding: const EdgeInsets.all(24), child: Text(_restoreError!, textAlign: TextAlign.center)),
                  TextButton(onPressed: _restoreSession, child: const Text('다시 연결')),
                  TextButton(onPressed: () async { await _session.signOut(); if (mounted) setState(() => _restoreError = null); }, child: const Text('다른 계정으로 로그인')),
                ])))
              : _loginId == null
              ? LoginScreen(key: const ValueKey('login'), onLogin: _login)
              : _nickname == null
              ? NicknameScreen(loginId: _loginId!, onSave: _saveNickname)
              : HomeScreen(
                key: const ValueKey('home'),
                loginId: _loginId!,
                nickname: _nickname!,
                isAdmin: _role == 'admin',
                onLogout: _logout,
                onNicknameChanged: _saveNickname,
              ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  late final String _remoteUrl;

  @override
  void initState() {
    super.initState();
    _remoteUrl =
        'https://raw.githubusercontent.com/SerenLucent/AST/main/Image/title.png?cacheBust=${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        key: const ValueKey('title-splash'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox.expand(
          child: Image.network(
            _remoteUrl,
            key: const ValueKey('title-splash-image'),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            },
            errorBuilder:
                (_, _, _) => const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: Text(
                      '타이틀 이미지를 불러오지 못했습니다.\n화면을 눌러 계속해 주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
