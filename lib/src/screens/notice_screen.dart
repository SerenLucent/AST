import 'package:flutter/material.dart';

import '../models/notice.dart';
import '../services/github_admin_service.dart';
import '../services/notice_repository.dart';
import '../widgets/github_token_dialog.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({
    super.key,
    required this.loginId,
    required this.nickname,
    this.isBoard = false,
    this.isAdmin = false,
  });

  final String loginId;
  final String nickname;
  final bool isBoard;
  final bool isAdmin;

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  late final NoticeRepository _repository;
  final _github = GithubAdminService();
  List<Notice> _notices = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.isBoard
            ? const NoticeRepository.board()
            : const NoticeRepository.notices();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notices = await _repository.fetch(forceRefresh: refresh);
      if (mounted) setState(() => _notices = notices);
    } catch (_) {
      if (mounted) setState(() => _error = '$_sectionName을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _ensureToken() async {
    if (await _github.token != null) return true;
    if (!mounted) return false;
    return showGithubTokenDialog(context, _github);
  }

  Future<void> _add() async {
    final draft = await showDialog<_NoticeDraft>(
      context: context,
      builder: (_) => _NoticeEditorDialog(sectionName: _sectionName),
    );
    if (draft == null || !mounted || !await _ensureToken()) return;
    List<Notice> latest;
    try {
      latest = await _repository.fetch(forceRefresh: true);
    } catch (_) {
      latest = _notices;
    }
    final notice = Notice(
      id: '${DateTime.now().microsecondsSinceEpoch}-${widget.loginId}',
      title: draft.title,
      memo: draft.memo,
      createdAt: DateTime.now(),
      authorId: widget.loginId,
      authorNickname: widget.nickname,
    );
    await _save([...latest, notice], '$_sectionName 게시물을 등록했습니다.');
  }

  Future<void> _edit(Notice notice) async {
    final draft = await showDialog<_NoticeDraft>(
      context: context,
      builder:
          (_) =>
              _NoticeEditorDialog(sectionName: _sectionName, existing: notice),
    );
    if (draft == null || !mounted || !await _ensureToken()) return;
    List<Notice> latest;
    try {
      latest = await _repository.fetch(forceRefresh: true);
    } catch (_) {
      latest = _notices;
    }
    final updated =
        latest.map((item) {
          if (item.id != notice.id) return item;
          return Notice(
            id: item.id,
            title: draft.title,
            memo: draft.memo,
            createdAt: item.createdAt,
            authorId: item.authorId,
            authorNickname: item.authorNickname,
          );
        }).toList();
    await _save(updated, '$_sectionName 게시물을 수정했습니다.');
  }

  Future<void> _delete(Notice notice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('공지사항 삭제'),
            content: Text('「${notice.title}」 게시물을 삭제할까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted || !await _ensureToken()) return;
    List<Notice> latest;
    try {
      latest = await _repository.fetch(forceRefresh: true);
    } catch (_) {
      latest = _notices;
    }
    await _save(
      latest.where((item) => item.id != notice.id).toList(),
      '$_sectionName 게시물을 삭제했습니다.',
    );
  }

  Future<void> _save(List<Notice> notices, String message) async {
    setState(() => _saving = true);
    try {
      if (widget.isBoard) {
        await _github.saveBoardPosts(notices);
      } else {
        await _github.saveNotices(notices);
      }
      notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() => _notices = notices);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _open(Notice notice) async {
    final action = await showDialog<String>(
      context: context,
      builder:
          (context) => _NoticeDetailDialog(
            notice: notice,
            isAdmin: widget.isAdmin,
            canManage:
                widget.isAdmin ||
                notice.authorId.toLowerCase() == widget.loginId.toLowerCase(),
          ),
    );
    if (!mounted) return;
    if (action == 'delete') await _delete(notice);
    if (action == 'edit') await _edit(notice);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _sectionName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : () => _load(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: _content(),
          ),
          if (_saving)
            const ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('작성'),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return ListView(
        children: const [
          SizedBox(height: 260),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [Center(child: Text(_error!))],
      );
    }
    if (_notices.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 180),
          const Icon(
            Icons.campaign_outlined,
            size: 62,
            color: Color(0xFF938C9E),
          ),
          const SizedBox(height: 16),
          Text(
            widget.isBoard ? '등록된 게시물이 없습니다.' : '등록된 공지사항이 없습니다.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF777184)),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _notices.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final notice = _notices[index];
        return ListTile(
          onTap: () => _open(notice),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 8,
          ),
          title: Text(
            notice.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          trailing: Text(
            _date(notice.createdAt),
            style: const TextStyle(color: Color(0xFF777184)),
          ),
        );
      },
    );
  }

  String _date(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  String get _sectionName => widget.isBoard ? '게시판' : '공지사항';
}

class _NoticeEditorDialog extends StatefulWidget {
  const _NoticeEditorDialog({required this.sectionName, this.existing});

  final String sectionName;
  final Notice? existing;

  @override
  State<_NoticeEditorDialog> createState() => _NoticeEditorDialogState();
}

class _NoticeEditorDialogState extends State<_NoticeEditorDialog> {
  final _titleController = TextEditingController();
  final _memoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.existing?.title ?? '';
    _memoController.text = widget.existing?.memo ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _confirm() {
    final title = _titleController.text.trim();
    final memo = _memoController.text.trim();
    if (title.isEmpty || memo.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목과 메모를 모두 입력해주세요.')));
      return;
    }
    Navigator.pop(context, _NoticeDraft(title: title, memo: memo));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${widget.sectionName} ${widget.existing == null ? '작성' : '수정'}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              maxLength: 60,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: '메모',
                alignLabelWithHint: true,
              ),
            ),
          ],
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
                    onPressed: _confirm,
                    child: const Text('확인'),
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

class _NoticeDetailDialog extends StatelessWidget {
  const _NoticeDetailDialog({
    required this.notice,
    required this.isAdmin,
    required this.canManage,
  });

  final Notice notice;
  final bool isAdmin;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(notice.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${notice.createdAt.year}.${notice.createdAt.month.toString().padLeft(2, '0')}.${notice.createdAt.day.toString().padLeft(2, '0')} · ${_authorLabel(notice)}',
              style: const TextStyle(color: Color(0xFF777184)),
            ),
            const SizedBox(height: 18),
            Text(notice.memo, style: const TextStyle(height: 1.55)),
          ],
        ),
      ),
      actions: [
        if (canManage)
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('삭제'),
          ),
        if (canManage)
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'edit'),
            child: const Text('수정'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  String _authorLabel(Notice notice) {
    if (!isAdmin || notice.authorId.isEmpty) return notice.authorNickname;
    return '${notice.authorNickname} (${notice.authorId})';
  }
}

class _NoticeDraft {
  const _NoticeDraft({required this.title, required this.memo});

  final String title;
  final String memo;
}
