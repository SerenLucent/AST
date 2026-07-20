import 'package:flutter_test/flutter_test.dart';

import 'package:ast_team_app/src/models/team_event.dart';

void main() {
  final event = TeamEvent(
    title: '당일 행사',
    scheduledAt: DateTime(2026, 7, 20, 20),
    location: '공연장',
  );

  test('행사 시간이 지나도 당일 23시 59분에는 표시한다', () {
    expect(event.isVisibleAt(DateTime(2026, 7, 20, 23, 59, 59)), isTrue);
  });

  test('다음 날 0시부터는 표시하지 않는다', () {
    expect(event.isVisibleAt(DateTime(2026, 7, 21)), isFalse);
  });

  test('다가오는 일정은 날짜 순서로 정렬한다', () {
    final later = TeamEvent(
      title: '다음 행사',
      scheduledAt: DateTime(2026, 7, 22, 19),
      location: '연습실',
    );
    expect(upcomingEvents([later, event], DateTime(2026, 7, 20)).first, event);
  });
}
