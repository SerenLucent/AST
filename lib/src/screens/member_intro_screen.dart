import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/member_profile.dart';
import '../services/github_admin_service.dart';
import '../services/member_repository.dart';
import '../widgets/github_token_dialog.dart';

class MemberIntroScreen extends StatefulWidget {
  const MemberIntroScreen({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<MemberIntroScreen> createState() => _MemberIntroScreenState();
}

class _MemberIntroScreenState extends State<MemberIntroScreen> {
  final _repository = MemberRepository();
  final _github = GithubAdminService();
  List<MemberProfile> _members = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await _repository.fetch(forceRefresh: refresh);
      if (mounted) setState(() => _members = members);
    } catch (_) {
      if (mounted) setState(() => _error = '팀원 소개를 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor() async {
    final draft = await showDialog<_MemberDraft>(
      context: context,
      builder: (_) => const _MemberEditorDialog(),
    );
    if (draft == null || !mounted) return;
    final savedToken = await _github.token;
    if (!mounted) return;
    if (savedToken == null) {
      final connected = await showGithubTokenDialog(context, _github);
      if (!connected || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      var imageUrl = '';
      if (draft.bytes != null && draft.fileName != null) {
        final extension = draft.fileName!.split('.').last.toLowerCase();
        final remoteName =
            'member_${DateTime.now().microsecondsSinceEpoch}.$extension';
        imageUrl = await _github.uploadMemberImage(
          fileName: remoteName,
          bytes: draft.bytes!,
        );
      }
      final latest = await _repository.fetch(forceRefresh: true);
      final member = MemberProfile(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        imageUrl: imageUrl,
        memo: draft.memo,
      );
      final updated = [...latest, member];
      await _github.saveMembers(updated);
      if (!mounted) return;
      setState(() => _members = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('팀원 소개를 등록했습니다.')));
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

  Future<bool> _ensureGithubToken() async {
    final savedToken = await _github.token;
    if (!mounted) return false;
    if (savedToken != null) return true;
    return showGithubTokenDialog(context, _github);
  }

  Future<void> _deleteMember(MemberProfile member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('팀원 삭제'),
            content: Text('${member.memo}\n\n이 팀원 소개를 삭제할까요?'),
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
    if (confirmed != true || !mounted || !await _ensureGithubToken()) return;
    setState(() => _saving = true);
    try {
      final latest = await _repository.fetch(forceRefresh: true);
      final updated = latest.where((item) => item.id != member.id).toList();
      await _github.saveMembers(updated);
      if (!mounted) return;
      setState(() => _members = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('팀원 소개를 삭제했습니다.')));
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

  Future<void> _openSorter() async {
    final sorted = await showDialog<List<MemberProfile>>(
      context: context,
      builder: (_) => _MemberSortDialog(members: _members),
    );
    if (sorted == null || !mounted || !await _ensureGithubToken()) return;
    setState(() => _saving = true);
    try {
      await _github.saveMembers(sorted);
      if (!mounted) return;
      setState(() => _members = sorted);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('팀원 순서를 저장했습니다.')));
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
          '팀원 소개',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (widget.isAdmin)
            IconButton(
              tooltip: '팀원 순서 변경',
              onPressed:
                  _loading || _saving || _members.length < 2
                      ? null
                      : _openSorter,
              icon: const Icon(Icons.swap_vert_rounded),
            ),
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
            child: _buildContent(),
          ),
          if (_saving)
            const ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton:
          widget.isAdmin
              ? FloatingActionButton(
                onPressed: _saving ? null : _openEditor,
                child: const Icon(Icons.add_rounded),
              )
              : null,
    );
  }

  Widget _buildContent() {
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
        padding: const EdgeInsets.all(20),
        children: [Center(child: Text(_error!))],
      );
    }
    if (_members.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 180),
          Icon(Icons.groups_2_outlined, size: 64, color: Color(0xFF938C9E)),
          SizedBox(height: 16),
          Text(
            '등록된 팀원 소개가 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF777184)),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final member = _members[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MemberImage(imageUrl: member.imageUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      member.memo,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                ),
                if (widget.isAdmin)
                  IconButton(
                    tooltip: '팀원 삭제',
                    onPressed: _saving ? null : () => _deleteMember(member),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MemberSortDialog extends StatefulWidget {
  const _MemberSortDialog({required this.members});

  final List<MemberProfile> members;

  @override
  State<_MemberSortDialog> createState() => _MemberSortDialogState();
}

class _MemberSortDialogState extends State<_MemberSortDialog> {
  late final List<MemberProfile> _members = [...widget.members];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('팀원 순서 변경'),
      content: SizedBox(
        width: 420,
        height: 430,
        child: ReorderableListView.builder(
          itemCount: _members.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final member = _members.removeAt(oldIndex);
              _members.insert(newIndex, member);
            });
          },
          itemBuilder: (context, index) {
            final member = _members[index];
            return ListTile(
              key: ValueKey(member.id),
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(
                member.memo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.drag_handle_rounded),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _members),
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _MemberEditorDialog extends StatefulWidget {
  const _MemberEditorDialog();

  @override
  State<_MemberEditorDialog> createState() => _MemberEditorDialogState();
}

class _MemberEditorDialogState extends State<_MemberEditorDialog> {
  final _memoController = TextEditingController();
  Uint8List? _bytes;
  String? _fileName;

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null || !mounted) return;
    setState(() {
      _bytes = file!.bytes;
      _fileName = file.name;
    });
  }

  void _confirm() {
    final memo = _memoController.text.trim();
    if (memo.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메모를 입력해주세요.')));
      return;
    }
    Navigator.pop(
      context,
      _MemberDraft(fileName: _fileName, bytes: _bytes, memo: memo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('팀원 소개 등록'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EBF8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFB8A9CE)),
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    _bytes == null
                        ? const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 58,
                          color: Color(0xFF6750A4),
                        )
                        : Image.memory(_bytes!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _memoController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '메모',
                hintText: '이름, 파트, 소개 등을 입력해주세요.',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('확인')),
      ],
    );
  }
}

class _MemberDraft {
  const _MemberDraft({
    required this.fileName,
    required this.bytes,
    required this.memo,
  });

  final String? fileName;
  final Uint8List? bytes;
  final String memo;
}

class _MemberImage extends StatelessWidget {
  const _MemberImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    const placeholder = SizedBox(
      width: 112,
      height: 112,
      child: ColoredBox(
        color: Color(0xFFE2E2E2),
        child: Icon(
          Icons.person_outline_rounded,
          size: 46,
          color: Color(0xFF888888),
        ),
      ),
    );
    if (imageUrl.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imageUrl,
        width: 112,
        height: 112,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}
