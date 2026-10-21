import 'package:flutter/material.dart';
import '../services/apps_script_gateway.dart';
import '../services/user_repository.dart';
import '../widgets/ast_wallet_widgets.dart';
import 'ast_home_screen.dart';

class AstHomeLobbyScreen extends StatefulWidget {
  const AstHomeLobbyScreen({super.key, required this.loginId});
  final String loginId;
  @override
  State<AstHomeLobbyScreen> createState() => _AstHomeLobbyScreenState();
}

class _AstHomeLobbyScreenState extends State<AstHomeLobbyScreen> {
  final _gateway = AppsScriptGateway();
  List<MapEntry<String, int>> _rows = [];
  Map<String, String> _names = {};
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _gateway.homeRequest({
        'action': 'astHomeGet',
        'loginId': widget.loginId,
      });
      try {
        final users = await UserRepository().fetch();
        _names = {for (final u in users) u.loginId.toLowerCase(): u.nickname};
      } catch (_) {}
      final totals = Map<String, dynamic>.from(
        (result['home'] as Map)['contributions'] as Map? ?? {},
      );
      final rows =
          totals.entries
              .map((e) => MapEntry(e.key, (e.value as num).toInt()))
              .toList()
            ..sort((a, b) {
              final order = b.value.compareTo(a.value);
              return order != 0 ? order : a.key.compareTo(b.key);
            });
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = '기여도를 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _gateway.close();
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
            onPressed:
                _loading || _error != null
                    ? null
                    : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => AstHomeScreen(loginId: widget.loginId),
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
