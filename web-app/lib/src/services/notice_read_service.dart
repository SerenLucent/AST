import 'package:shared_preferences/shared_preferences.dart';

import '../models/notice.dart';

class NoticeReadService {
  const NoticeReadService();

  String _key(String loginId, {required bool isBoard}) =>
      'read_${isBoard ? 'board' : 'notices'}_${loginId.trim().toLowerCase()}';

  Future<Set<String>> readIds(String loginId, {required bool isBoard}) async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_key(loginId, isBoard: isBoard)) ??
            const <String>[])
        .toSet();
  }

  Future<int> unreadCount(
    String loginId,
    Iterable<Notice> notices, {
    required bool isBoard,
  }) async {
    final read = await readIds(loginId, isBoard: isBoard);
    return notices.where((notice) => !read.contains(notice.id)).length;
  }

  Future<void> markRead(
    String loginId,
    String noticeId, {
    required bool isBoard,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _key(loginId, isBoard: isBoard);
    final ids =
        (preferences.getStringList(key) ?? const <String>[]).toSet()
          ..add(noticeId);
    await preferences.setStringList(key, ids.toList()..sort());
  }
}
