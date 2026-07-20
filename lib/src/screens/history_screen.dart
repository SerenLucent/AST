import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/history_file.dart';
import '../services/download_service.dart';
import '../services/github_admin_service.dart';
import '../services/history_repository.dart';
import '../widgets/github_token_dialog.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _repository = HistoryRepository();
  final _downloadService = DownloadService();
  final _adminService = GithubAdminService();
  List<HistoryFile> _files = const [];
  bool _loading = true;
  String? _error;
  String? _busyName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await _repository.fetchFiles(forceRefresh: forceRefresh);
      if (mounted) setState(() => _files = files);
    } catch (_) {
      if (mounted) setState(() => _error = '행사 자료를 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _ensureToken() async {
    if (await _adminService.token != null) return true;
    if (!mounted) return false;
    return showGithubTokenDialog(context, _adminService);
  }

  Future<void> _download(HistoryFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('행사 자료 다운로드'),
            content: Text('${file.name}\n\n저장 위치를 선택할까요?'),
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
    setState(() => _busyName = file.name);
    try {
      final saved = await _downloadService.downloadAndSaveFile(
        fileName: file.name,
        downloadUrl: file.downloadUrl,
        mimeType: file.mimeType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(saved ? '${file.name} 저장 완료' : '저장을 취소했습니다.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('다운로드하지 못했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _busyName = null);
    }
  }

  Future<void> _upload() async {
    if (!await _ensureToken()) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'ppt', 'pptx', 'doc', 'docx'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null || !mounted) return;

    HistoryFile? existing;
    for (final history in _files) {
      if (history.name == file.name) {
        existing = history;
        break;
      }
    }
    if (existing != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('같은 이름의 자료가 있습니다'),
              content: Text('${file.name}\n\n기존 파일을 교체할까요?'),
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

    setState(() => _busyName = file.name);
    try {
      await _adminService.uploadHistoryFile(
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _busyName = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '행사 히스토리',
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
      body: SafeArea(child: _content()),
      floatingActionButton:
          widget.isAdmin
              ? FloatingActionButton.extended(
                onPressed: _busyName == null ? _upload : null,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('자료 업로드'),
              )
              : null,
    );
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton.tonal(
          onPressed: _load,
          child: Text('$_error\n다시 시도'),
        ),
      );
    }
    if (_files.isEmpty) return const Center(child: Text('등록된 행사 자료가 없습니다.'));
    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          _LatestFileCard(
            file: _files.first,
            onDownload: () => _download(_files.first),
          ),
          const SizedBox(height: 24),
          Text(
            '전체 행사 기록',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final file in _files) ...[
            _HistoryTile(
              file: file,
              busy: _busyName == file.name,
              enabled: _busyName == null,
              onDownload: () => _download(file),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _LatestFileCard extends StatelessWidget {
  const _LatestFileCard({required this.file, required this.onDownload});
  final HistoryFile file;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF287D6C), Color(0xFF45A18E)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Colors.white, size: 42),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '가장 최근 자료',
                  style: TextStyle(
                    color: Color(0xFFDDF6EF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.file,
    required this.busy,
    required this.enabled,
    required this.onDownload,
  });
  final HistoryFile file;
  final bool busy;
  final bool enabled;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Text(
            file.extension.toUpperCase(),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          file.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(file.formattedSize),
        trailing: IconButton.filledTonal(
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
      ),
    );
  }
}
