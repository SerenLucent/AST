import 'package:ast_team_app/src/services/schedule_repository.dart';
import 'package:ast_team_app/src/models/schedule_entry.dart';
import 'package:ast_team_app/src/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schedule JSON is decoded and sorted by time', () {
    final entries = ScheduleRepository().decode('''
      {"schemaVersion":1,"schedules":[
        {"id":"b","scheduledAt":"2026-07-20T19:30:00","memo":"공연","authorId":"two","authorNickname":"둘"},
        {"id":"a","scheduledAt":"2026-07-20T10:00:00","memo":"연습","authorId":"one","authorNickname":"하나"}
      ]}
    ''');

    expect(entries.map((entry) => entry.id), ['a', 'b']);
    expect(entries.first.memo, '연습');
    expect(entries.last.authorNickname, '둘');
  });

  test('closest schedule keeps an earlier event visible until day ends', () {
    ScheduleEntry entry(String id, DateTime time) => ScheduleEntry(
      id: id,
      scheduledAt: time,
      memo: id,
      authorId: 'test',
      authorNickname: '테스트',
    );
    final entries = [
      entry('yesterday', DateTime(2026, 7, 20, 23, 50)),
      entry('today', DateTime(2026, 7, 21, 9)),
      entry('tomorrow', DateTime(2026, 7, 22, 10)),
    ];

    expect(
      closestVisibleSchedule(entries, DateTime(2026, 7, 21, 23, 59))?.id,
      'today',
    );
    expect(
      closestVisibleSchedule(entries, DateTime(2026, 7, 22))?.id,
      'tomorrow',
    );
  });
}
