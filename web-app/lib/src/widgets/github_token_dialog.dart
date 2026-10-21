import 'dart:async';

import 'package:flutter/material.dart';

import '../services/github_admin_service.dart';

Future<bool> showGithubTokenDialog(
  BuildContext context,
  GithubAdminService service,
) async {
  final connected = await showDialog<bool>(
    context: context,
    builder: (_) => _GithubTokenDialog(service: service),
  );
  return connected ?? false;
}

class _GithubTokenDialog extends StatefulWidget {
  const _GithubTokenDialog({required this.service});

  final GithubAdminService service;

  @override
  State<_GithubTokenDialog> createState() => _GithubTokenDialogState();
}

class _GithubTokenDialogState extends State<_GithubTokenDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = '토큰을 입력해주세요.');
      return;
    }
    if (!value.startsWith('github_pat_') && !value.startsWith('ghp_')) {
      setState(() => _error = '올바른 GitHub 토큰 형식인지 확인해주세요.');
      return;
    }
    unawaited(widget.service.saveToken(value));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('GitHub 저장소 연결'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SerenLucent/AST 저장소의 Contents 쓰기 권한이 있는 Fine-grained token을 입력하세요.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'GitHub token',
              errorText: _error,
              prefixIcon: const Icon(Icons.key_rounded),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }
}
