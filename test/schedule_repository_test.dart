import 'package:ast_team_app/src/services/schedule_repository.dart';
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
}
