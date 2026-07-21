import 'package:flutter/material.dart';

import '../models/schedule_entry.dart';
import '../services/schedule_repository.dart';
import 'history_screen.dart';
import 'member_intro_screen.dart';
import 'notice_screen.dart';
import 'schedule_screen.dart';
import 'score_library_screen.dart';

ScheduleEntry? closestVisibleSchedule(
  Iterable<ScheduleEntry> entries,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final visible =
      entries.where((entry) {
          final day = DateTime(
            entry.scheduledAt.year,
            entry.scheduledAt.month,
            entry.scheduledAt.day,
          );
          return !day.isBefore(today);
        }).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return visible.firstOrNull;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.loginId,
    required this.nickname,
    required this.isAdmin,
    required this.onLogout,
    required this.onNicknameChanged,
  });

  final String loginId;
  final String nickname;
  final bool isAdmin;
  final Future<void> Function() onLogout;
  final Future<void> Function(String nickname) onNicknameChanged;

  static const _menuItems = [
    _MenuItem(
      '연습 스케줄',
      '이번 주 연습 시간을 확인하세요',
      Icons.schedule_outlined,
      Color(0xFF3D6CB4),
    ),
    _MenuItem(
      '악보 자료실',
      '필요한 악보를 찾아 다운로드하세요',
      Icons.picture_as_pdf_outlined,
      Color(0xFFD85B61),
    ),
    _MenuItem(
      '행사 히스토리',
      '지난 행사 자료를 확인하세요',
      Icons.event_available_outlined,
      Color(0xFF287D6C),
    ),
    _MenuItem(
      '팀원 소개',
      '우리 팀의 목소리를 만나보세요',
      Icons.groups_2_outlined,
      Color(0xFF6750A4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AST',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4),
        ),
        actions: [
          TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              '로그아웃',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _WelcomeCard(nickname: nickname),
            const SizedBox(height: 26),
            Text(
              '팀 메뉴',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _menuItems.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: .88,
              ),
              itemBuilder:
                  (context, index) => _MenuCard(
                    item: _menuItems[index],
                    isAdmin: isAdmin,
                    loginId: loginId,
                    nickname: nickname,
                  ),
            ),
            const SizedBox(height: 26),
            Text(
              '가장 가까운 일정',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _ClosestSchedule(
              loginId: loginId,
              nickname: nickname,
              isAdmin: isAdmin,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => NoticeScreen(
                      loginId: loginId,
                      nickname: nickname,
                      isAdmin: isAdmin,
                    ),
              ),
            );
          }
          if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => NoticeScreen(
                      loginId: loginId,
                      nickname: nickname,
                      isBoard: true,
                      isAdmin: isAdmin,
                    ),
              ),
            );
          }
          if (index == 3) {
            _changeNickname(context);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            label: '공지',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: '게시판',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: '내 정보',
          ),
        ],
      ),
    );
  }

  Future<void> _changeNickname(BuildContext context) async {
    final changed = await showDialog<String>(
      context: context,
      builder: (_) => _NicknameEditDialog(currentNickname: nickname),
    );
    if (changed == null || changed == nickname) return;
    await onNicknameChanged(changed);
  }
}

class _NicknameEditDialog extends StatefulWidget {
  const _NicknameEditDialog({required this.currentNickname});

  final String currentNickname;

  @override
  State<_NicknameEditDialog> createState() => _NicknameEditDialogState();
}

class _NicknameEditDialogState extends State<_NicknameEditDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentNickname);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = '닉네임을 입력해주세요.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('닉네임 변경'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 20,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: '닉네임',
          errorText: _error,
          prefixIcon: const Icon(Icons.person_outline_rounded),
        ),
      ),
      actions: [
        SizedBox(
          width: double.maxFinite,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('저장'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.nickname});
  final String nickname;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6750A4), Color(0xFF8D72C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x336750A4),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$nickname님, 안녕하세요!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '오늘도 멋진 하모니를 만들어볼까요?',
                  style: TextStyle(color: Color(0xFFECE5FA), height: 1.4),
                ),
              ],
            ),
          ),
          const Icon(Icons.music_note_rounded, color: Colors.white, size: 52),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.item,
    required this.isAdmin,
    required this.loginId,
    required this.nickname,
  });
  final _MenuItem item;
  final bool isAdmin;
  final String loginId;
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final isSchedule = item.icon == Icons.schedule_outlined;
    final isMemberIntro = item.icon == Icons.groups_2_outlined;
    final title = isSchedule ? '연습 / 공연 스케줄' : item.title;
    final subtitle = isSchedule ? '연습과 공연 일정을 함께 확인하세요.' : item.subtitle;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          if (isSchedule) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => ScheduleScreen(
                      loginId: loginId,
                      nickname: nickname,
                      isAdmin: isAdmin,
                    ),
              ),
            );
            return;
          }
          if (isMemberIntro) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MemberIntroScreen(isAdmin: isAdmin),
              ),
            );
            return;
          }
          if (item.title == '악보 자료실') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ScoreLibraryScreen(isAdmin: isAdmin),
              ),
            );
            return;
          }
          if (item.title == '행사 히스토리') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HistoryScreen(isAdmin: isAdmin),
              ),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${item.title} 화면은 다음 단계에서 연결합니다.')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(item.icon, color: item.color, size: 29),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF777184),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosestSchedule extends StatefulWidget {
  const _ClosestSchedule({
    required this.loginId,
    required this.nickname,
    required this.isAdmin,
  });

  final String loginId;
  final String nickname;
  final bool isAdmin;

  @override
  State<_ClosestSchedule> createState() => _ClosestScheduleState();
}

class _ClosestScheduleState extends State<_ClosestSchedule> {
  final _repository = ScheduleRepository();
  ScheduleEntry? _entry;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await _repository.fetch(forceRefresh: true);
      if (mounted) {
        setState(() {
          _entry = closestVisibleSchedule(entries, DateTime.now());
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final entry = _entry;
    if (entry == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          children: [
            Icon(Icons.event_busy_outlined, color: Color(0xFF777184)),
            SizedBox(width: 12),
            Text('예정된 일정이 없습니다.', style: TextStyle(color: Color(0xFF777184))),
          ],
        ),
      );
    }
    return _ClosestScheduleCard(
      entry: entry,
      isAdmin: widget.isAdmin,
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder:
                (_) => ScheduleScreen(
                  loginId: widget.loginId,
                  nickname: widget.nickname,
                  isAdmin: widget.isAdmin,
                  initialDay: entry.scheduledAt,
                ),
          ),
        );
        await _load();
      },
    );
  }
}

class _ClosestScheduleCard extends StatelessWidget {
  const _ClosestScheduleCard({
    required this.entry,
    required this.isAdmin,
    required this.onTap,
  });

  final ScheduleEntry entry;
  final bool isAdmin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              _DateBadge(date: entry.scheduledAt),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.memo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_timeLabel(entry.scheduledAt)} · ${_authorLabel(entry)}',
                      style: const TextStyle(color: Color(0xFF777184)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  String _timeLabel(DateTime date) {
    final period = date.hour < 12 ? '오전' : '오후';
    final hour = date.hour % 12;
    return '$period $hour:${date.minute.toString().padLeft(2, '0')}';
  }

  String _authorLabel(ScheduleEntry entry) {
    if (!isAdmin || entry.authorId.isEmpty) return entry.authorNickname;
    return '${entry.authorNickname} (${entry.authorId})';
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EBF8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.month}월',
            style: const TextStyle(
              color: Color(0xFF6750A4),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${date.day}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.title, this.subtitle, this.icon, this.color);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}
