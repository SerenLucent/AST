import 'package:ast_team_app/src/models/history_file.dart';
import 'package:ast_team_app/src/services/history_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  HistoryFile file(String name) => HistoryFile(
    name: name,
    path: 'Doc/$name',
    sha: name,
    downloadUrl: 'https://example.com/$name',
    size: 100,
  );

  test('dated history files come first in newest-first order', () {
    final files = [
      file('신규 프로젝트 기획안.pptx'),
      file('2025-12-22.pdf'),
      file('2026-01-19.pdf'),
    ]..sort(compareHistoryFiles);

    expect(files.map((item) => item.name), [
      '2026-01-19.pdf',
      '2025-12-22.pdf',
      '신규 프로젝트 기획안.pptx',
    ]);
  });

  test('date is read from the start of a history filename', () {
    expect(historyDateFromName('2026-07-20 행사.pdf'), DateTime(2026, 7, 20));
    expect(historyDateFromName('행사 자료.pdf'), isNull);
  });
}
