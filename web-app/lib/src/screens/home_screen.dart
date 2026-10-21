import 'package:flutter/material.dart';
import 'package:nwc_player_lab/main.dart' show Lab;

import '../models/schedule_entry.dart';
import '../services/ast_wallet_controller.dart';
import '../services/ast_wallet_repository.dart';
import '../services/ast_reward_sound.dart';
import '../widgets/ast_reward_effect.dart';
import '../widgets/ast_wallet_widgets.dart';
import '../services/schedule_repository.dart';
import '../services/generation_repository.dart';
import '../services/notice_repository.dart';
import '../services/notice_read_service.dart';
import '../services/user_repository.dart';
import 'history_screen.dart';
import 'member_intro_screen.dart';
import 'member_management_screen.dart';
import 'notice_screen.dart';
import 'schedule_screen.dart';
import 'score_library_screen.dart';
import 'update_screen.dart';
import 'game_lobby_screen.dart';
import 'ast_home_lobby_screen.dart';

ScheduleEntry? closestVisibleSchedule(
  Iterable<ScheduleEntry> entries,
  DateTime now,
) {
  return closestVisibleSchedules(entries, now).firstOrNull;
}

List<ScheduleEntry> closestVisibleSchedules(
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
  if (visible.isEmpty) return const [];
  final closest = visible.first.scheduledAt;
  return visible
      .where(
        (entry) =>
            entry.scheduledAt.year == closest.year &&
            entry.scheduledAt.month == closest.month &&
            entry.scheduledAt.day == closest.day,
      )
      .toList();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.loginId,
    required this.nickname,
    required this.isAdmin,
    required this.onLogout,
    required this.onNicknameChanged,
    this.walletRepository,
    this.rewardSound,
  });

  final String loginId;
  final String nickname;
  final bool isAdmin;
  final Future<void> Function() onLogout;
  final Future<void> Function(String nickname) onNicknameChanged;
  final AstWalletRepository? walletRepository;
  final AstRewardSound? rewardSound;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late AstWalletRepository _walletRepository;
  late AstWalletController _wallet;
  late final _users = UserRepository().fetch();
  String get loginId => widget.loginId;
  String get nickname => widget.nickname;
  bool get isAdmin => widget.isAdmin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _walletRepository = widget.walletRepository ?? ServerAstWalletRepository();
    _createWallet();
  }

  void _createWallet() {
    _wallet = AstWalletController(
      loginId: loginId,
      repository: _walletRepository,
    );
    _wallet.refresh();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loginId.trim().toLowerCase() !=
            loginId.trim().toLowerCase() ||
        oldWidget.walletRepository != widget.walletRepository) {
      _wallet.dispose();
      if (oldWidget.walletRepository != widget.walletRepository) {
        if (oldWidget.walletRepository == null) _walletRepository.close();
        _walletRepository =
            widget.walletRepository ?? ServerAstWalletRepository();
      }
      _createWallet();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _wallet.setActive(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wallet.dispose();
    if (widget.walletRepository == null) _walletRepository.close();
    super.dispose();
  }

  static const _menuItems = [
    _MenuItem(
      '연습 / 공연 스케줄',
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
      'NWC 플레이어',
      'NWC 악보를 보고 파트별로 연주하세요',
      Icons.queue_music_rounded,
      Color(0xFFEF8C35),
    ),
    _MenuItem(
      '팀원 소개',
      '우리 팀의 목소리를 만나보세요',
      Icons.groups_2_outlined,
      Color(0xFF6750A4),
    ),
    _MenuItem(
      '행사 히스토리',
      '지난 행사 자료를 확인하세요',
      Icons.event_available_outlined,
      Color(0xFF287D6C),
    ),
    _MenuItem(
      '업데이트 확인',
      '새로운 AST 버전을 확인하세요',
      Icons.system_update_alt_rounded,
      Color(0xFF5568A8),
    ),
    _MenuItem(
      'Game 하기',
      '타이밍 슈터',
      Icons.sports_esports_outlined,
      Color(0xFF2D857D),
    ),
    _MenuItem(
      'AST 집 꾸미기',
      '아스트로 함께 꾸미는 우리 집',
      Icons.chair_outlined,
      Color(0xFF947247),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AstRewardEffect(
      controller: _wallet,
      sound: widget.rewardSound,
      builder:
          (context, reward) => Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  const Text(
                    'AST',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: ListenableBuilder(
                      listenable: reward,
                      builder:
                          (context, _) => Transform.scale(
                            scale: reward.badgeScale,
                            child: AstBalanceBadge(
                              controller: _wallet,
                              displayedBalance: reward.balance,
                              coinAnchorKey: reward.targetKey,
                            ),
                          ),
                    ),
                  ),
                ],
              ),
              actions: [
                if (isAdmin)
                  IconButton(
                    tooltip: '멤버 관리',
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MemberManagementScreen(),
                          ),
                        ),
                    icon: const Icon(Icons.manage_accounts_outlined),
                  ),
                if (MediaQuery.sizeOf(context).width < 380)
                  IconButton(
                    tooltip: '로그아웃',
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout_rounded),
                  )
                else
                  TextButton.icon(
                    onPressed: widget.onLogout,
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
                  ListenableBuilder(
                    listenable: reward,
                    builder:
                        (context, _) => AstWelcomeCard(
                          nickname: nickname,
                          controller: _wallet,
                          onClaim: reward.claim,
                          coinAnchorKey: reward.sourceKey,
                          hideCoin: reward.hideSource,
                        ),
                  ),
                  const SizedBox(height: 26),
                  _ClosestSchedule(
                    loginId: loginId,
                    nickname: nickname,
                    isAdmin: isAdmin,
                  ),
                  const SizedBox(height: 26),
                  Text(
                    '팀 메뉴',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FutureBuilder(
                    future: _users,
                    builder: (context, snapshot) {
                      final users = snapshot.data ?? const [];
                      final current = users.where(
                        (user) =>
                            user.loginId.toLowerCase() == loginId.toLowerCase(),
                      );
                      final user = current.firstOrNull;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _menuItems.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 1.02,
                            ),
                        itemBuilder:
                            (context, index) => _MenuCard(
                              item: _menuItems[index],
                              onHomeClosed: () => _wallet.refresh(),
                              isAdmin: isAdmin,
                              canUploadScores: user?.canUploadScores ?? false,
                              canUploadHistory: user?.canUploadHistory ?? false,
                              loginId: loginId,
                              nickname: nickname,
                            ),
                      );
                    },
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _UnreadNavigation(
              loginId: loginId,
              nickname: nickname,
              isAdmin: isAdmin,
              onProfile: () => _changeNickname(context),
            ),
          ),
    );
  }

  Future<void> _changeNickname(BuildContext context) async {
    final changed = await showDialog<String>(
      context: context,
      builder: (_) => _NicknameEditDialog(currentNickname: nickname),
    );
    if (changed == null || changed == nickname) return;
    await widget.onNicknameChanged(changed);
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

class _UnreadNavigation extends StatefulWidget {
  const _UnreadNavigation({
    required this.loginId,
    required this.nickname,
    required this.isAdmin,
    required this.onProfile,
  });

  final String loginId;
  final String nickname;
  final bool isAdmin;
  final VoidCallback onProfile;

  @override
  State<_UnreadNavigation> createState() => _UnreadNavigationState();
}

class _UnreadNavigationState extends State<_UnreadNavigation> {
  final _readService = const NoticeReadService();
  int noticeCount = 0;
  int boardCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final results = await Future.wait([
        const NoticeRepository.notices().fetch(),
        const NoticeRepository.board().fetch(),
      ]);
      final counts = await Future.wait([
        _readService.unreadCount(widget.loginId, results[0], isBoard: false),
        _readService.unreadCount(widget.loginId, results[1], isBoard: true),
      ]);
      if (!mounted) return;
      setState(() {
        noticeCount = counts[0];
        boardCount = counts[1];
      });
    } catch (_) {
      // A badge refresh failure must not block the home screen.
    }
  }

  Future<void> _openSection(bool isBoard) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => NoticeScreen(
              loginId: widget.loginId,
              nickname: widget.nickname,
              isBoard: isBoard,
              isAdmin: widget.isAdmin,
            ),
      ),
    );
    await _loadCounts();
  }

  Widget _badge(IconData icon, int count) => Badge.count(
    count: count,
    isLabelVisible: count > 0,
    backgroundColor: Colors.red,
    textColor: Colors.white,
    child: Icon(icon),
  );

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: 0,
    onDestinationSelected: (index) {
      if (index == 1) _openSection(false);
      if (index == 2) _openSection(true);
      if (index == 3) widget.onProfile();
    },
    destinations: [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: '홈',
      ),
      NavigationDestination(
        icon: _badge(Icons.campaign_outlined, noticeCount),
        selectedIcon: _badge(Icons.campaign, noticeCount),
        label: '공지',
      ),
      NavigationDestination(
        icon: _badge(Icons.chat_bubble_outline, boardCount),
        selectedIcon: _badge(Icons.chat_bubble, boardCount),
        label: '게시판',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        label: '내 정보',
      ),
    ],
  );
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.item,
    this.onHomeClosed,
    required this.isAdmin,
    required this.canUploadScores,
    required this.canUploadHistory,
    required this.loginId,
    required this.nickname,
  });
  final VoidCallback? onHomeClosed;
  final _MenuItem item;
  final bool isAdmin;
  final bool canUploadScores;
  final bool canUploadHistory;
  final String loginId;
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final isSchedule = item.icon == Icons.schedule_outlined;
    final isMemberIntro = item.icon == Icons.groups_2_outlined;
    final title = item.title;
    final subtitle = isSchedule ? '연습과 공연 일정을 함께 확인하세요.' : item.subtitle;
    return Material(
      key: ValueKey('menu-${item.title}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          if (item.title == 'AST 집 꾸미기') {
            Navigator.of(context)
                .push(
                  MaterialPageRoute<void>(
                    builder: (_) => AstHomeLobbyScreen(loginId: loginId),
                  ),
                )
                .then((_) => onHomeClosed?.call());
            return;
          }
          if (item.title == 'Game 하기') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) =>
                        GameLobbyScreen(loginId: loginId, nickname: nickname),
              ),
            );
            return;
          }
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
                builder:
                    (_) => MemberIntroScreen(
                      isAdmin: isAdmin,
                      loginId: loginId,
                      nickname: nickname,
                    ),
              ),
            );
            return;
          }
          if (item.title == '악보 자료실') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => ScoreLibraryScreen(
                      isAdmin: isAdmin,
                      canUpload: canUploadScores,
                    ),
              ),
            );
            return;
          }
          if (item.title == 'NWC 플레이어') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => const Lab(
                      embedded: true,
                      soundfontAsset:
                          'packages/nwc_player_lab/assets/soundfonts/piano.sf2',
                    ),
              ),
            );
            return;
          }
          if (item.title == '행사 히스토리') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => HistoryScreen(
                      isAdmin: isAdmin,
                      canUpload: canUploadHistory,
                    ),
              ),
            );
            return;
          }
          if (item.title == '업데이트 확인') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const UpdateScreen()),
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
  List<ScheduleEntry> _entries = const [];
  List<GenerationOption> _generationOptions =
      GenerationRepository.defaultOptions;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _repository.fetch(forceRefresh: true),
        GenerationRepository().fetchOptions(),
      ]);
      final entries = values[0] as List<ScheduleEntry>;
      if (mounted) {
        setState(() {
          _entries = closestVisibleSchedules(entries, DateTime.now());
          _generationOptions = values[1] as List<GenerationOption>;
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
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClosestScheduleHeading(entries: [], options: []),
          SizedBox(height: 14),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    final heading = _ClosestScheduleHeading(
      entries: _entries,
      options: _generationOptions,
    );
    if (_entries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(Icons.event_busy_outlined, color: Color(0xFF777184)),
                SizedBox(width: 12),
                Text(
                  '예정된 일정이 없습니다.',
                  style: TextStyle(color: Color(0xFF777184)),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,
        const SizedBox(height: 14),
        _ClosestScheduleCard(
          entry: _entries.first,
          isAdmin: widget.isAdmin,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => ScheduleScreen(
                      loginId: widget.loginId,
                      nickname: widget.nickname,
                      isAdmin: widget.isAdmin,
                      initialDay: _entries.first.scheduledAt,
                    ),
              ),
            );
            await _load();
          },
        ),
      ],
    );
  }
}

class _ClosestScheduleHeading extends StatelessWidget {
  const _ClosestScheduleHeading({required this.entries, required this.options});

  final List<ScheduleEntry> entries;
  final List<GenerationOption> options;

  @override
  Widget build(BuildContext context) {
    final generations =
        entries
            .map((entry) => entry.generation)
            .where((generation) => generation.isNotEmpty)
            .toSet();
    return Wrap(
      spacing: 7,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '가장 가까운 일정',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (entries.isNotEmpty)
          Text(
            '${entries.length}건',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        for (final generation in generations)
          _GenerationBadge(
            generation: generation,
            color:
                options
                    .where((option) => option.id == generation)
                    .firstOrNull
                    ?.color ??
                '#9E9E9E',
          ),
      ],
    );
  }
}

class _GenerationBadge extends StatelessWidget {
  const _GenerationBadge({required this.generation, required this.color});

  final String generation;
  final String color;

  @override
  Widget build(BuildContext context) {
    final parsed = Color(
      int.tryParse('FF${color.replaceFirst('#', '')}', radix: 16) ?? 0xFF9E9E9E,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: parsed,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        generation,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
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
