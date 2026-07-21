import 'package:flutter/material.dart';

import '../models/schedule_entry.dart';
import '../services/github_admin_service.dart';
import '../services/schedule_repository.dart';
import '../widgets/github_token_dialog.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    required this.loginId,
    required this.nickname,
    this.isAdmin = false,
    this.initialDay,
  });
  final String loginId;
  final String nickname;
  final bool isAdmin;
  final DateTime? initialDay;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _repository = ScheduleRepository();
  final _github = GithubAdminService();
  late DateTime _month;
  late DateTime _day;
  List<ScheduleEntry> _entries = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDay ?? DateTime.now();
    _month = DateTime(initial.year, initial.month);
    _day = DateTime(initial.year, initial.month, initial.day);
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _repository.fetch(forceRefresh: refresh);
      if (mounted) setState(() => _entries = entries);
    } catch (_) {
      if (mounted) setState(() => _error = '일정을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ScheduleEntry> _onDay(DateTime day) =>
      _entries
          .where(
            (entry) =>
                entry.scheduledAt.year == day.year &&
                entry.scheduledAt.month == day.month &&
                entry.scheduledAt.day == day.day,
          )
          .toList();

  Future<bool> _connect() async {
    if (await _github.token != null) return true;
    if (!mounted) return false;
    return showGithubTokenDialog(context, _github);
  }

  Future<void> _changeToken() async {
    final changed = await showGithubTokenDialog(context, _github);
    if (!mounted || !changed) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('GitHub 토큰을 새 값으로 변경했습니다.')));
  }

  Future<void> _add() async {
    final draft = await showModalBottomSheet<_Draft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _Editor(day: _day),
    );
    if (draft == null || !mounted || !await _connect()) return;
    List<ScheduleEntry> latest;
    try {
      latest = await _repository.fetch(forceRefresh: true);
    } catch (_) {
      latest = _entries;
    }
    final entry = ScheduleEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}-${widget.loginId}',
      scheduledAt: DateTime(
        _day.year,
        _day.month,
        _day.day,
        draft.hour,
        draft.minute,
      ),
      memo: draft.memo,
      authorId: widget.loginId,
      authorNickname: widget.nickname,
    );
    await _save([...latest, entry], '일정을 등록했습니다.');
  }

  Future<void> _delete(ScheduleEntry entry) async {
    if (!await _connect()) return;
    List<ScheduleEntry> latest;
    try {
      latest = await _repository.fetch(forceRefresh: true);
    } catch (_) {
      latest = _entries;
    }
    await _save(
      latest.where((item) => item.id != entry.id).toList(),
      '일정을 삭제했습니다.',
    );
  }

  Future<void> _save(List<ScheduleEntry> entries, String message) async {
    setState(() => _saving = true);
    try {
      await _github.saveSchedules(entries);
      entries.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      if (!mounted) return;
      setState(() => _entries = entries);
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

  @override
  Widget build(BuildContext context) {
    final selected = _onDay(_day);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '연습 / 공연 스케줄',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'GitHub 토큰 변경',
            onPressed: _changeToken,
            icon: const Icon(Icons.key_rounded),
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : () => _load(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _Calendar(
                  month: _month,
                  selected: _day,
                  entries: _entries,
                  previous:
                      () => setState(
                        () => _month = DateTime(_month.year, _month.month - 1),
                      ),
                  next:
                      () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      ),
                  select: (value) => setState(() => _day = value),
                ),
                const SizedBox(height: 20),
                Text(
                  '${_day.month}월 ${_day.day}일 일정',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  _Message(_error!)
                else if (selected.isEmpty)
                  const _Message('등록된 일정이 없습니다.')
                else
                  ...selected.map(
                    (entry) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.schedule),
                        title: Text(
                          _time(entry.scheduledAt),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${entry.memo}\n등록: ${_authorLabel(entry)}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          onPressed: _saving ? null : () => _delete(entry),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_saving)
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _add,
        icon: const Icon(Icons.add),
        label: const Text('일정 등록'),
      ),
    );
  }

  String _authorLabel(ScheduleEntry entry) {
    if (!widget.isAdmin || entry.authorId.isEmpty) {
      return entry.authorNickname;
    }
    return '${entry.authorNickname} (${entry.authorId})';
  }

  String _time(DateTime date) {
    final period = date.hour < 12 ? '오전' : '오후';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$period $hour:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.month,
    required this.selected,
    required this.entries,
    required this.previous,
    required this.next,
    required this.select,
  });
  final DateTime month;
  final DateTime selected;
  final List<ScheduleEntry> entries;
  final VoidCallback previous;
  final VoidCallback next;
  final ValueChanged<DateTime> select;

  @override
  Widget build(BuildContext context) {
    final leading = DateTime(month.year, month.month).weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((leading + days + 6) ~/ 7) * 7;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: previous,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${month.year}년 ${month.month}월',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: next,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: [
                for (final text in ['일', '월', '화', '수', '목', '금', '토'])
                  Expanded(
                    child: Center(
                      child: Text(
                        text,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: .9,
              ),
              itemBuilder: (context, index) {
                final number = index - leading + 1;
                if (number < 1 || number > days) return const SizedBox();
                final day = DateTime(month.year, month.month, number);
                final active = _same(day, selected);
                final marked = entries.any(
                  (entry) => _same(day, entry.scheduledAt),
                );
                return InkWell(
                  onTap: () => select(day),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color:
                          active ? Theme.of(context).colorScheme.primary : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$number',
                          style: TextStyle(
                            color:
                                active
                                    ? Colors.white
                                    : (index % 7 == 0 ? Colors.red : null),
                            fontWeight:
                                active || marked ? FontWeight.w800 : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (marked)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  active
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Editor extends StatefulWidget {
  const _Editor({required this.day});
  final DateTime day;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final memo = TextEditingController();
  String period = '오후';
  int hour = 7;
  int minute = 0;

  @override
  void dispose() {
    memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.day.month}월 ${widget.day.day}일 일정 등록',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: period,
                  decoration: const InputDecoration(labelText: '오전/오후'),
                  items:
                      ['오전', '오후']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => period = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: hour,
                  decoration: const InputDecoration(labelText: '시'),
                  items: List.generate(
                    12,
                    (v) => DropdownMenuItem(value: v, child: Text('$v시')),
                  ),
                  onChanged: (v) => setState(() => hour = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: minute,
                  decoration: const InputDecoration(labelText: '분'),
                  items: List.generate(
                    6,
                    (v) => DropdownMenuItem(
                      value: v * 10,
                      child: Text('${v * 10}분'),
                    ),
                  ),
                  onChanged: (v) => setState(() => minute = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: memo,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '메모',
              hintText: '연습 장소, 공연명, 준비물 등을 적어주세요.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (memo.text.trim().isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('메모를 입력해주세요.')));
                  return;
                }
                var converted = hour;
                if (period == '오후') converted = hour + 12;
                Navigator.pop(
                  context,
                  _Draft(converted, minute, memo.text.trim()),
                );
              },
              child: const Text('확인'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Draft {
  const _Draft(this.hour, this.minute, this.memo);
  final int hour;
  final int minute;
  final String memo;
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.event_available_outlined),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    ),
  );
}
