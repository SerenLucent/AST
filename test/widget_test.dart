import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ast_team_app/src/app.dart';

void main() {
  testWidgets('로그인 화면을 표시한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AstTeamApp());
    await tester.pumpAndSettle();

    expect(find.text('우리의 목소리를 한곳에'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
  });
}
