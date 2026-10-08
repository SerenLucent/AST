import 'package:flutter/material.dart';

import '../services/game_ranking_repository.dart';
import '../services/game_version_service.dart';
import 'timing_shooter_screen.dart';

class GameLobbyScreen extends StatefulWidget {
  const GameLobbyScreen({
    super.key,
    required this.loginId,
    required this.nickname,
    this.repository,
    this.versionService,
    this.requireLatestVersion = false,
  });
  final String loginId;
  final String nickname;
  final GameRankingRepository? repository;
  final GameVersionService? versionService;
  final bool requireLatestVersion;
  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  late final GameRankingRepository _repository;
  late final GameVersionService _versionService;
  List<GameRankingEntry> _entries = [];
  bool _loading = true;
  bool _launching = false;
  String? _error;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? GameRankingRepository();
    _versionService = widget.versionService ?? GameVersionService();
    _load();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repository.fetch();
      if (mounted && version == _loadVersion) setState(() => _entries = rows);
    } catch (_) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = '랭킹을 불러오지 못했습니다.');
      }
    } finally {
      if (mounted && version == _loadVersion) setState(() => _loading = false);
    }
  }

  Future<void> _start() async {
    if (_launching) return;
    setState(() => _launching = true);
    if (widget.requireLatestVersion) {
      try {
        final version = await _versionService.check();
        if (!mounted) return;
        if (!version.allowed) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('앱 업데이트가 필요합니다'),
              content: Text(
                '현재 버전: ${version.current}\n최신 버전: ${version.latest}\n\n최신 앱을 설치한 후 게임을 시작해주세요.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
          if (mounted) setState(() => _launching = false);
          return;
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _launching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('앱 버전을 확인할 수 없습니다. 인터넷 연결을 확인하고 다시 시도해주세요.'),
          ),
        );
        return;
      }
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TimingShooterScreen(loginId: widget.loginId),
      ),
    );
    if (!mounted) return;
    setState(() => _launching = false);
    await _load();
  }

  @override
  void dispose() {
    if (widget.repository == null) _repository.dispose();
    if (widget.versionService == null) _versionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final playerKey = GameRankingRepository.playerKeyFor(widget.loginId);
    final own = _entries
        .where((entry) => entry.playerKey == playerKey)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('타이밍 슈터'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: '랭킹 새로고침',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('이번 주 기록'),
                        const SizedBox(height: 6),
                        Text(
                          widget.nickname,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('주간 최고 점수'),
                      Text(
                        _loading && own == null
                            ? '-'
                            : _error != null && own == null
                            ? '-'
                            : _number(own?.bestScore ?? 0),
                        key: const ValueKey('own-game-score'),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  SizedBox(width: 40, child: Text('순위')),
                  Expanded(child: Text('닉네임')),
                  Text('최고 점수'),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading && _entries.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          IconButton(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            tooltip: '다시 불러오기',
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _entries.isEmpty ? 1 : _entries.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (_entries.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: Text('아직 등록된 점수가 없어요.')),
                            );
                          }
                          final entry = _entries[index];
                          final mine = entry.playerKey == playerKey;
                          return ColoredBox(
                            color: mine
                                ? colors.primaryContainer
                                : Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 18,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      mine ? widget.nickname : entry.nickname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _number(entry.bestScore),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            if (_error != null && _entries.isNotEmpty)
              Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _launching ? null : _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('게임 시작'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _number(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}
