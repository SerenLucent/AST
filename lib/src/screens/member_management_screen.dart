import 'package:flutter/material.dart';

import '../models/team_user.dart';
import '../services/github_admin_service.dart';
import '../services/user_repository.dart';

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  final _repository = UserRepository();
  final _github = GithubAdminService();
  List<TeamUser> _users = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await _repository.fetch(forceRefresh: true);
      users.sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));
      if (mounted) setState(() => _users = users);
    } catch (_) {
      if (mounted) setState(() => _error = '멤버 목록을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPermissions(TeamUser user) async {
    var score = user.canUploadScores;
    var history = user.canUploadHistory;
    final updated = await showDialog<TeamUser>(
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
    if (updated == null || !mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '멤버 관리',
          style: TextStyle(fontWeight: FontWeight.w800),
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
                      '${user.loginId}\n최근 접속: ${_dateTime(user.lastLoginAt)}',
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
