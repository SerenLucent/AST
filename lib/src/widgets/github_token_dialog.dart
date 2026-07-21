import 'package:flutter/material.dart';

import '../services/github_admin_service.dart';

Future<bool> showGithubTokenDialog(
  BuildContext context,
  GithubAdminService service,
) async {
  final controller = TextEditingController();
  var validating = false;
  String? error;
  final connected = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => StatefulBuilder(
          builder:
              (context, setDialogState) => AlertDialog(
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
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
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
                              bool valid;
                              try {
                                valid = await service.validateToken(value);
                              } catch (_) {
                                if (!dialogContext.mounted) return;
                                setDialogState(() {
                                  validating = false;
                                  error =
                                      '연결 시간이 초과됐습니다. 인터넷 연결을 확인하고 다시 시도해주세요.';
                                });
                                return;
                              }
                              if (!dialogContext.mounted) return;
                              if (!valid) {
                                setDialogState(() {
                                  validating = false;
                                  error = '저장소 접근 권한을 확인해주세요.';
                                });
                                return;
                              }
                              try {
                                await service.saveToken(value);
                              } catch (_) {
                                if (!dialogContext.mounted) return;
                                setDialogState(() {
                                  validating = false;
                                  error = '토큰을 휴대폰에 저장하지 못했습니다. 다시 시도해주세요.';
                                });
                                return;
                              }
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
