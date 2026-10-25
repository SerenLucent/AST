import 'package:flutter/material.dart';

import '../models/team_user.dart';
import '../services/github_admin_service.dart';
import '../services/generation_repository.dart';
import '../services/user_repository.dart';
import '../services/web_access_repository.dart';

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({
    super.key,
    this.userRepository,
    this.webAccessRepository,
  });

  final UserRepository? userRepository;
  final WebAccessRepository? webAccessRepository;

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  late final UserRepository _repository;
  late final WebAccessRepository _webAccessRepository;
  final _generationRepository = GenerationRepository();
  final _github = GithubAdminService();
  List<TeamUser> _users = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, DateTime> _webAccess = {};
  bool _webLoading = true;
  bool _webNeedsAuth = false;
  String? _webError;
  int _webRequest = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.userRepository ?? UserRepository();
    _webAccessRepository = widget.webAccessRepository ?? WebAccessRepository();
    _load();
    _loadWebAccess();
  }

  @override
  void dispose() {
    _webRequest++;
    _webAccessRepository.close();
    super.dispose();
  }

  DateTime _latestAccess(TeamUser user) {
    final web = _webAccess[user.loginId.toLowerCase()];
    return web != null && web.isAfter(user.lastLoginAt)
        ? web
        : user.lastLoginAt;
  }

  void _sortUsers() =>
      _users.sort((a, b) => _latestAccess(b).compareTo(_latestAccess(a)));

  Future<void> _loadWebAccess() async {
    final request = ++_webRequest;
    setState(() {
      _webLoading = true;
      _webNeedsAuth = false;
      _webError = null;
    });
    try {
      final dates = await _webAccessRepository.fetch();
      if (!mounted || request != _webRequest) return;
      setState(() {
        _webAccess = dates;
        _sortUsers();
      });
    } on WebAccessAuthRequired {
      if (!mounted || request != _webRequest) return;
      setState(() {
        _webAccess = {};
        _webNeedsAuth = true;
        _sortUsers();
      });
    } catch (_) {
      if (!mounted || request != _webRequest) return;
      setState(() => _webError = '웹 기록 조회 실패 · 웹 서버 배포 상태와 연결을 확인해 주세요.');
    } finally {
      if (mounted && request == _webRequest) {
        setState(() => _webLoading = false);
      }
    }
  }

  Future<void> _authenticateWebAccess() async {
    final authenticated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WebAccessLoginDialog(repository: _webAccessRepository),
    );
    if (authenticated == true && mounted) await _loadWebAccess();
  }

  String _webAccessLabel(TeamUser user) {
    if (_webNeedsAuth) return '관리자 인증 필요';
    if (_webLoading) return '확인 중…';
    if (_webError != null) return '조회 실패';
    final date = _webAccess[user.loginId.toLowerCase()];
    return date == null ? '기록 없음' : _dateTime(date);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _repository.fetch(forceRefresh: true);
      if (mounted) {
        setState(() {
          _users = users;
          _sortUsers();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '멤버 목록을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPermissions(TeamUser user) async {
    var score = user.canUploadScores;
    var history = user.canUploadHistory;
    final result = await showDialog<Object>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    user.nickname.isEmpty ? user.loginId : user.nickname,
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('아이디: ${user.loginId}'),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('악보 업로드'),
                        value: score,
                        onChanged:
                            (value) => setDialogState(() => score = value!),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('히스토리 업로드'),
                        value: history,
                        onChanged:
                            (value) => setDialogState(() => history = value!),
                      ),
                      const Divider(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                          onPressed:
                              () => Navigator.pop(
                                context,
                                const _DeleteUserRequest(),
                              ),
                          icon: const Icon(Icons.person_remove_outlined),
                          label: const Text('해당 사용자 삭제'),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed:
                          () => Navigator.pop(
                            context,
                            user.copyWith(
                              canUploadScores: score,
                              canUploadHistory: history,
                            ),
                          ),
                      child: const Text('저장'),
                    ),
                  ],
                ),
          ),
    );
    if (!mounted || result == null) return;
    if (result is _DeleteUserRequest) {
      await _deleteUser(user);
      return;
    }
    final updated = result as TeamUser;
    setState(() => _saving = true);
    try {
      final users = [..._users];
      users[users.indexWhere((item) => item.loginId == user.loginId)] = updated;
      await _github.saveUsers(users);
      if (mounted) setState(() => _users = users);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteUser(TeamUser user) async {
    final displayName = user.nickname.isEmpty ? user.loginId : user.nickname;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('사용자 삭제'),
            content: Text(
              '$displayName (${user.loginId}) 사용자를 삭제할까요?\n'
              '로그인 계정과 기수 정보가 함께 삭제됩니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final users = [
        for (final item in _users)
          if (item.loginId.toLowerCase() != user.loginId.toLowerCase()) item,
      ];
      await _github.saveUsers(users);
      final generations = await _generationRepository.fetch(forceRefresh: true);
      generations.remove(user.loginId.toLowerCase());
      await _github.saveGenerations(generations);
      if (mounted) {
        setState(() => _users = users);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$displayName 사용자를 삭제했습니다.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '멤버 관리',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: '접속 기록 새로고침',
            onPressed:
                _loading || _webLoading || _saving
                    ? null
                    : () {
                      _load();
                      _loadWebAccess();
                    },
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_webNeedsAuth ? 76 : 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child:
                _webNeedsAuth
                    ? TextButton.icon(
                      onPressed: _authenticateWebAccess,
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text(
                        '웹 접속 기록: 웹 관리자 인증',
                        textAlign: TextAlign.center,
                      ),
                    )
                    : Text(
                      _webError ??
                          '웹 기록은 로그인·자동 로그인·화면 복귀 시 갱신됩니다.\n기록 없음: 기능 적용 후 아직 웹 접속 기록이 없습니다.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
          ),
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : _users.isEmpty
              ? const Center(child: Text('등록된 사용자가 없습니다.'))
              : ListView.separated(
                itemCount: _users.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return ListTile(
                    enabled: !_saving,
                    onTap: () => _openPermissions(user),
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      user.nickname.isEmpty ? '(닉네임 미등록)' : user.nickname,
                    ),
                    subtitle: Text(
                      '${user.loginId}\n앱 최근 접속: ${_dateTime(user.lastLoginAt)}\n웹 최근 접속: ${_webAccessLabel(user)}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              ),
    );
  }

  String _dateTime(DateTime value) =>
      '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _DeleteUserRequest {
  const _DeleteUserRequest();
}

class _WebAccessLoginDialog extends StatefulWidget {
  const _WebAccessLoginDialog({required this.repository});
  final WebAccessRepository repository;
  @override
  State<_WebAccessLoginDialog> createState() => _WebAccessLoginDialogState();
}

class _WebAccessLoginDialogState extends State<_WebAccessLoginDialog> {
  final _id = TextEditingController(text: 'admin_naokist');
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.authenticate(_id.text.trim(), _password.text);
      _password.clear();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error =
                  error is WebAccessException
                      ? error.message
                      : '인증하지 못했습니다. 웹 관리자 계정과 연결을 확인해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('웹 관리자 인증'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('웹 관리자 비밀번호로 접속 기록만 조회합니다. 비밀번호는 저장하지 않습니다.'),
            TextField(
              controller: _id,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: '웹 관리자 아이디'),
            ),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: '웹 관리자 비밀번호'),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('인증'),
        ),
      ],
    ),
  );
}
