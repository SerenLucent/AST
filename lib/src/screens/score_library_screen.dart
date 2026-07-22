import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/score_file.dart';
import '../services/download_service.dart';
import '../services/github_admin_service.dart';
import '../services/score_repository.dart';

class ScoreLibraryScreen extends StatefulWidget {
  const ScoreLibraryScreen({
    super.key,
    required this.isAdmin,
    this.canUpload = false,
  });

  final bool isAdmin;
  final bool canUpload;

  @override
  State<ScoreLibraryScreen> createState() => _ScoreLibraryScreenState();
}

class _ScoreLibraryScreenState extends State<ScoreLibraryScreen> {
  final _repository = ScoreRepository();
  final _downloadService = DownloadService();
  final _adminService = GithubAdminService();
  final _searchController = TextEditingController();
  List<ScoreFile> _scores = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _downloadingName;
  String? _adminBusyName;

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('악보 다운로드'),
            content: Text('${score.name}\n\n저장 위치를 선택할까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('저장 위치 선택'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

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

  Future<bool> _ensureGithubToken({bool forceDialog = false}) async {
    if (!forceDialog && await _adminService.token != null) return true;
    if (!mounted) return false;

    final controller = TextEditingController();
    var validating = false;
    String? error;
    final connected = await showDialog<bool>(
      context: context,
      barrierDismissible: !forceDialog,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('GitHub 관리자 연결'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SerenLucent/AST 저장소의 Contents 쓰기 권한이 있는 Fine-grained token을 입력하세요. 토큰은 이 기기의 보안 저장소에만 보관됩니다.',
                          style: TextStyle(height: 1.45),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: 'GitHub token',
                            errorText: error,
                            prefixIcon: const Icon(Icons.key_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          validating
                              ? null
                              : () => Navigator.pop(dialogContext, false),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed:
                          validating
                              ? null
                              : () async {
                                final value = controller.text.trim();
                                if (value.isEmpty) {
                                  setDialogState(() => error = '토큰을 입력해주세요.');
                                  return;
                                }
                                setDialogState(() {
                                  validating = true;
                                  error = null;
                                });
                                final valid = await _adminService.validateToken(
                                  value,
                                );
                                if (!dialogContext.mounted) return;
                                if (!valid) {
                                  setDialogState(() {
                                    validating = false;
                                    error = '저장소 접근 권한을 확인해주세요.';
                                  });
                                  return;
                                }
                                await _adminService.saveToken(value);
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext, true);
                                }
                              },
                      child: Text(validating ? '확인 중...' : '연결'),
                    ),
                  ],
                ),
          ),
    );
    controller.dispose();
    return connected ?? false;
  }

  Future<void> _uploadPdf() async {
    if (!await _ensureGithubToken()) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null || !mounted) return;

    ScoreFile? existing;
    for (final score in _scores) {
      if (score.name == file.name) {
        existing = score;
        break;
      }
    }
    if (existing != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('같은 이름의 악보가 있습니다'),
              content: Text('${file.name}\n\n기존 파일을 새 파일로 교체할까요?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('교체'),
                ),
              ],
            ),
      );
      if (replace != true) return;
    }

    setState(() => _adminBusyName = file.name);
    try {
      await _adminService.uploadPdf(
        fileName: file.name,
        bytes: file.bytes!,
        existingSha: existing?.sha,
      );
      await _load(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${file.name} 업로드 완료')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _adminBusyName = null);
    }
  }

  Future<void> _delete(ScoreFile score) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('악보 삭제'),
            content: Text('${score.name}\n\nGitHub에서 이 파일을 삭제할까요?'),
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
    if (confirmed != true || !await _ensureGithubToken()) return;

    setState(() => _adminBusyName = score.name);
    try {
      await _adminService.deleteScore(score);
      await _load(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${score.name} 삭제 완료')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _adminBusyName = null);
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
      floatingActionButton:
          widget.isAdmin || widget.canUpload
              ? FloatingActionButton.extended(
                onPressed: _adminBusyName == null ? _uploadPdf : null,
                icon:
                    _adminBusyName == null
                        ? const Icon(Icons.upload_file_rounded)
                        : const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                label: const Text('악보 업로드'),
              )
              : null,
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
              isAdmin: widget.isAdmin,
              adminBusy: _adminBusyName == scores[index].name,
              onDelete: () => _delete(scores[index]),
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
    required this.isAdmin,
    required this.adminBusy,
    required this.onDelete,
  });
  final ScoreFile score;
  final bool busy;
  final bool enabled;
  final VoidCallback onDownload;
  final bool isAdmin;
  final bool adminBusy;
  final VoidCallback onDelete;

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
            if (isAdmin)
              IconButton(
                tooltip: '삭제',
                onPressed: enabled && !adminBusy ? onDelete : null,
                color: Theme.of(context).colorScheme.error,
                icon:
                    adminBusy
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
