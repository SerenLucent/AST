import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/member_profile.dart';
import '../services/github_admin_service.dart';
import '../services/generation_repository.dart';
import '../services/member_repository.dart';
import '../services/user_repository.dart';
import '../models/team_user.dart';

class MemberIntroScreen extends StatefulWidget {
  const MemberIntroScreen({
    super.key,
    required this.isAdmin,
    this.loginId = '',
    this.nickname = '',
  });

  final bool isAdmin;
  final String loginId;
  final String nickname;

  @override
  State<MemberIntroScreen> createState() => _MemberIntroScreenState();
}

class _MemberIntroScreenState extends State<MemberIntroScreen> {
  final _repository = MemberRepository();
  final _github = GithubAdminService();
  List<MemberProfile> _members = [];
  List<TeamUser> _users = [];
  List<GenerationOption> _generationOptions =
      GenerationRepository.defaultOptions;
  Map<String, String> _colors = const {};
  String? _selectedGeneration;
  bool _generationPrompted = false;
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
      final values = await Future.wait([
        _repository.fetch(forceRefresh: refresh),
        UserRepository().fetch(forceRefresh: refresh),
        _repository.fetchGenerationColors(),
        GenerationRepository().fetch(forceRefresh: refresh),
        GenerationRepository().fetchOptions(),
      ]);
      final members = values[0] as List<MemberProfile>;
      final generationMap = values[3] as Map<String, List<String>>;
      if (mounted) {
        setState(() {
          _members = members;
          _users = [
            for (final user in values[1] as List<TeamUser>)
              user.copyWith(
                generations:
                    generationMap[user.loginId.toLowerCase()] ?? const [],
              ),
          ];
          _colors = values[2] as Map<String, String>;
          _generationOptions = values[4] as List<GenerationOption>;
          final own =
              _users
                  .where(
                    (user) =>
                        user.loginId.toLowerCase() ==
                        widget.loginId.toLowerCase(),
                  )
                  .firstOrNull;
          _selectedGeneration ??= own?.primaryGeneration;
        });
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _maybeAskGeneration(),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = '팀원 소개를 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _maybeAskGeneration() async {
    if (_generationPrompted || !mounted) return;
    _generationPrompted = true;
    final index = _users.indexWhere(
      (u) => u.loginId.toLowerCase() == widget.loginId.toLowerCase(),
    );
    final memberExists =
        index >= 0 &&
        _users[index].memberId.isNotEmpty &&
        _members.any((member) => member.id == _users[index].memberId);
    if (!memberExists || index < 0 || _users[index].generations.isNotEmpty) {
      return;
    }
    await _showGenerationEditor(
      initial: const <String>{},
      barrierDismissible: false,
      cancelLabel: '다음에',
    );
  }

  TeamUser? get _ownUser =>
      _users
          .where(
            (user) =>
                user.loginId.toLowerCase() == widget.loginId.toLowerCase(),
          )
          .firstOrNull;

  Future<void> _editOwnGenerations() async {
    final own = _ownUser;
    if (own == null || _saving) return;
    await _showGenerationEditor(initial: own.generations.toSet());
  }

  Future<void> _showGenerationEditor({
    required Set<String> initial,
    bool barrierDismissible = true,
    String cancelLabel = '취소',
  }) async {
    final selected = <String>{...initial};
    final result = await showDialog<Set<String>>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, update) => AlertDialog(
                  title: const Text('기수 정보 선택'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('복수 선택 가능'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children:
                            _generationOptions
                                .where((option) => option.memberVisible)
                                .map((option) => option.id)
                                .map(
                                  (g) => FilterChip(
                                    label: Text(g),
                                    selected: selected.contains(g),
                                    onSelected:
                                        (v) => update(
                                          () =>
                                              v
                                                  ? selected.add(g)
                                                  : selected.remove(g),
                                        ),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(cancelLabel),
                    ),
                    FilledButton(
                      onPressed:
                          selected.isEmpty
                              ? null
                              : () => Navigator.pop(context, selected),
                      child: const Text('확인'),
                    ),
                  ],
                ),
          ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    setState(() => _saving = true);
    try {
      final latestGenerations = await GenerationRepository().fetch(
        forceRefresh: true,
      );
      latestGenerations[widget.loginId
          .toLowerCase()] = TeamUser.sortGenerations(result);
      await _github.saveGenerations(latestGenerations);
      final updated =
          _users
              .map(
                (u) =>
                    u.loginId.toLowerCase() == widget.loginId.toLowerCase()
                        ? u.copyWith(
                          generations: TeamUser.sortGenerations(result),
                        )
                        : u,
              )
              .toList();
      if (mounted) {
        setState(() {
          _users = updated;
          _selectedGeneration = TeamUser.sortGenerations(result).first;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('내 기수 정보를 수정했습니다.')));
      }
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

  Color _generationColor(MemberProfile member) {
    final user = _userFor(member);
    final hasGeneration =
        user?.generations.any((generation) => generation != 'Guest') ?? false;
    return hasGeneration ? const Color(0xFFFFC107) : const Color(0xFFD5CEE2);
  }

  TeamUser? _userFor(MemberProfile member) =>
      _users.where((user) => user.memberId == member.id).firstOrNull;

  Color _starColor(String generation) {
    final configured =
        _generationOptions
            .where((option) => option.id == generation)
            .firstOrNull
            ?.color;
    final hex = configured ?? _colors[generation] ?? '#9E9E9E';
    return Color(
      int.tryParse('FF${hex.replaceFirst('#', '')}', radix: 16) ?? 0xFF9E9E9E,
    );
  }

  List<MemberProfile> get _sortedMembers {
    final selected = _selectedGeneration;
    if (selected == null) return _members;
    final usersByMemberId = {
      for (final user in _users)
        if (user.memberId.isNotEmpty) user.memberId: user,
    };
    final originalPositions = {
      for (var index = 0; index < _members.length; index++)
        _members[index].id: index,
    };
    return [..._members]..sort((a, b) {
      final aUser = usersByMemberId[a.id];
      final bUser = usersByMemberId[b.id];
      final countComparison = compareTeamUsersByGeneration(
        aUser,
        bUser,
        selected,
      );
      if (countComparison != 0) return countComparison;
      return (originalPositions[a.id] ?? 0).compareTo(
        originalPositions[b.id] ?? 0,
      );
    });
  }

  Future<void> _openEditor([MemberProfile? existing]) async {
    final draft = await showDialog<_MemberDraft>(
      context: context,
      builder: (_) => _MemberEditorDialog(existing: existing),
    );
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    try {
      var imageUrl = existing?.imageUrl ?? '';
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
        id: existing?.id ?? '${DateTime.now().microsecondsSinceEpoch}',
        name: draft.name,
        imageUrl: imageUrl,
        memo: draft.memo,
      );
      final updated =
          existing == null
              ? [...latest, member]
              : latest
                  .map((item) => item.id == existing.id ? member : item)
                  .toList();
      await _github.saveMembers(updated);
      if (!mounted) return;
      setState(() => _members = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('팀원 소개를 ${existing == null ? '등록' : '수정'}했습니다.'),
        ),
      );
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

  Future<void> _deleteMember(MemberProfile member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('팀원 삭제'),
            content: Text('${member.name}\n\n이 팀원 소개를 삭제할까요?'),
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
    if (confirmed != true || !mounted) return;
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
    if (sorted == null || !mounted) return;
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
                onPressed: _saving ? null : () => _openEditor(),
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
    final sorted =
        _sortedMembers
            .where(
              (member) =>
                  !(_userFor(member)?.generations.contains('Guest') ?? false),
            )
            .toList();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: sorted.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '기수별 우선 보기',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value:
                          _generationOptions.any(
                                (option) =>
                                    option.memberVisible &&
                                    option.id == _selectedGeneration,
                              )
                              ? _selectedGeneration
                              : null,
                      decoration: const InputDecoration(labelText: '기수'),
                      hint: const Text('기수 선택'),
                      items:
                          _generationOptions
                              .where((option) => option.memberVisible)
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option.id,
                                  child: Text(option.id),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) =>
                              setState(() => _selectedGeneration = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed:
                        _ownUser == null || _saving
                            ? null
                            : _editOwnGenerations,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('내 기수 수정'),
                  ),
                ],
              ),
            ],
          );
        }
        final member = sorted[index - 1];
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: _generationColor(member), width: 2.5),
          ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((_userFor(member)?.generations
                                    .where(
                                      (generation) => generation != 'Guest',
                                    )
                                    .toList() ??
                                const <String>[])
                            .isNotEmpty) ...[
                          Row(
                            children: [
                              for (final generation
                                  in _userFor(member)!.generations)
                                if (generation != 'Guest')
                                  Padding(
                                    padding: const EdgeInsets.only(right: 3),
                                    child: Text(
                                      '★',
                                      style: TextStyle(
                                        color: _starColor(generation),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          member.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (member.memo.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            member.memo,
                            style: const TextStyle(height: 1.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_canEdit(member))
                  Column(
                    children: [
                      IconButton(
                        tooltip: '팀원 수정',
                        onPressed: _saving ? null : () => _openEditor(member),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      if (widget.isAdmin)
                        IconButton(
                          tooltip: '팀원 삭제',
                          onPressed:
                              _saving ? null : () => _deleteMember(member),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _canEdit(MemberProfile member) =>
      widget.isAdmin ||
      _users.any(
        (user) =>
            user.loginId.toLowerCase() == widget.loginId.toLowerCase() &&
            user.memberId.isNotEmpty &&
            user.memberId == member.id,
      );
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
          buildDefaultDragHandles: false,
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
                member.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.drag_handle_rounded),
                ),
              ),
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
  const _MemberEditorDialog({this.existing});

  final MemberProfile? existing;

  @override
  State<_MemberEditorDialog> createState() => _MemberEditorDialogState();
}

class _MemberEditorDialogState extends State<_MemberEditorDialog> {
  final _nameController = TextEditingController();
  final _memoController = TextEditingController();
  Uint8List? _bytes;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.existing?.name ?? '';
    _memoController.text = widget.existing?.memo ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
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
    final name = _nameController.text.trim();
    final memo = _memoController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이름을 입력해주세요.')));
      return;
    }
    Navigator.pop(
      context,
      _MemberDraft(fileName: _fileName, bytes: _bytes, name: name, memo: memo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('팀원 소개 ${widget.existing == null ? '등록' : '수정'}'),
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
                        ? widget.existing?.imageUrl.isNotEmpty == true
                            ? Image.network(
                              widget.existing!.imageUrl,
                              fit: BoxFit.cover,
                            )
                            : const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 58,
                              color: Color(0xFF6750A4),
                            )
                        : Image.memory(_bytes!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              maxLength: 30,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            const SizedBox(height: 12),
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
    required this.name,
    required this.memo,
  });

  final String? fileName;
  final Uint8List? bytes;
  final String name;
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
