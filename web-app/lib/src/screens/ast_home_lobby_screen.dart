import 'dart:async';

import 'package:flutter/material.dart';
import '../services/ast_home_contribution_repository.dart';
import '../services/user_repository.dart';
import '../widgets/ast_wallet_widgets.dart';
import 'ast_home_screen.dart';

class AstHomeLobbyScreen extends StatefulWidget {
  const AstHomeLobbyScreen({
    super.key,
    required this.loginId,
    this.repository,
    this.userRepository,
  });
  final String loginId;
  final AstHomeContributionRepository? repository;
  final UserRepository? userRepository;
  @override
  State<AstHomeLobbyScreen> createState() => _AstHomeLobbyScreenState();
}

class _AstHomeLobbyScreenState extends State<AstHomeLobbyScreen> {
  late final AstHomeContributionRepository _repository;
  late final UserRepository _userRepository;
  List<MapEntry<String, int>> _rows = [];
  Map<String, String> _names = {};
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AstHomeContributionRepository();
    _userRepository = widget.userRepository ?? UserRepository();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    // Names are optional: a slow/failed nickname lookup must not hold up totals.
    unawaited(_loadNames(generation));
    try {
      final rows = await _repository.fetch();
      if (mounted && generation == _loadGeneration) {
        setState(() => _rows = rows);
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = '기여도를 불러오지 못했습니다.');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadNames(int generation) async {
    try {
      final users = await _userRepository.fetch();
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _names = {
            for (final u in users) u.loginId.trim().toLowerCase(): u.nickname,
          };
        });
      }
    } catch (_) {
      // Keep existing names or show login IDs when the directory is unavailable.
    }
  }

  @override
  void dispose() {
    if (widget.repository == null) _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('AST 집 꾸미기'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            '우리 집 기여도',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const Text('가구 구매에 사용한 누적 아스트'),
        Expanded(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _rows.isEmpty
                  ? const Center(child: Text('아직 기여 기록이 없습니다.'))
                  : ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
                      final r = _rows[index];
                      return ListTile(
                        leading: Text('${index + 1}'),
                        title: Text(
                          _names[r.key]?.isNotEmpty == true
                              ? _names[r.key]!
                              : r.key,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AstCoin(size: 24),
                            const SizedBox(width: 6),
                            Text('${r.value} AST'),
                          ],
                        ),
                      );
                    },
                  ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton.icon(
            // The leaderboard is informational. The game still loads and checks
            // the authoritative wallet/state through its existing server bridge.
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AstHomeScreen(loginId: widget.loginId),
                ),
              );
              if (mounted) {
                _load();
              }
            },
            icon: const Icon(Icons.home),
            label: const Text('집 꾸미기 입장'),
          ),
        ),
      ],
    ),
  );
}
