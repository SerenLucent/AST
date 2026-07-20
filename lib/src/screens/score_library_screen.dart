import 'package:flutter/material.dart';

import '../models/score_file.dart';
import '../services/download_service.dart';
import '../services/score_repository.dart';

class ScoreLibraryScreen extends StatefulWidget {
  const ScoreLibraryScreen({super.key});

  @override
  State<ScoreLibraryScreen> createState() => _ScoreLibraryScreenState();
}

class _ScoreLibraryScreenState extends State<ScoreLibraryScreen> {
  final _repository = ScoreRepository();
  final _downloadService = DownloadService();
  final _searchController = TextEditingController();
  List<ScoreFile> _scores = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _downloadingName;

  List<ScoreFile> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _scores;
    return _scores
        .where((score) => score.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scores = await _repository.fetchScores(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() => _scores = scores);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '악보 목록을 불러오지 못했습니다.\n인터넷 연결을 확인해주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _download(ScoreFile score) async {
    setState(() => _downloadingName = score.name);
    try {
      final saved = await _downloadService.downloadAndSave(score);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(saved ? '${score.name} 저장 완료' : '저장을 취소했습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('다운로드하지 못했습니다. 다시 시도해주세요.')));
    } finally {
      if (mounted) setState(() => _downloadingName = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scores = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '악보 자료실',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: '곡명 또는 버전 검색',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon:
                      _query.isEmpty
                          ? null
                          : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                ),
              ),
            ),
            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '총 ${scores.length}개의 PDF',
                    style: const TextStyle(color: Color(0xFF777184)),
                  ),
                ),
              ),
            Expanded(child: _content(scores)),
          ],
        ),
      ),
    );
  }

  Widget _content(List<ScoreFile> scores) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 54,
              color: Color(0xFF777184),
            ),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.tonal(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (scores.isEmpty) return const Center(child: Text('검색 결과가 없습니다.'));
    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        itemCount: scores.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder:
            (context, index) => _ScoreTile(
              score: scores[index],
              busy: _downloadingName == scores[index].name,
              enabled: _downloadingName == null,
              onDownload: () => _download(scores[index]),
            ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.score,
    required this.busy,
    required this.enabled,
    required this.onDownload,
  });
  final ScoreFile score;
  final bool busy;
  final bool enabled;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECEC),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Color(0xFFD85B61),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    score.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    score.formattedSize,
                    style: const TextStyle(
                      color: Color(0xFF777184),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: '다운로드',
              onPressed: enabled ? onDownload : null,
              icon:
                  busy
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.download_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
