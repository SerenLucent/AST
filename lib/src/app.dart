import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/nickname_screen.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';

class AstTeamApp extends StatefulWidget {
  const AstTeamApp({super.key});

  @override
  State<AstTeamApp> createState() => _AstTeamAppState();
}

class _AstTeamAppState extends State<AstTeamApp> {
  final SessionService _session = SessionService();
  bool _loading = true;
  String? _loginId;
  String? _nickname;
  String? _role;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final profileFuture = _session.currentProfile();
    await Future.wait<void>([
      Future<void>.delayed(const Duration(seconds: 1)),
      profileFuture.then((_) {}),
    ]);
    final profile = await profileFuture;
    if (!mounted) return;
    setState(() {
      _loginId = profile?.loginId;
      _nickname = profile?.nickname;
      _role = profile?.role;
      _loading = false;
    });
  }

  Future<bool> _login(String id, String password) async {
    if (!_session.matchesTeamPassword(password)) return false;
    final profile = await _session.signIn(id);
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
      home:
          _loading
              ? const _SplashScreen()
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
  const _SplashScreen();

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
      backgroundColor: const Color(0xFFF8F3EC),
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/title.png',
              key: const ValueKey('title-splash-image'),
              fit: BoxFit.cover,
            ),
            Image.network(
              _remoteUrl,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
