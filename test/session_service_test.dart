import 'package:ast_team_app/src/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('only admin_naokist receives the admin role', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SessionService();

    final formerAdmin = await service.signIn('admin');
    final currentAdmin = await service.signIn('ADMIN_NAOKIST');

    expect(formerAdmin.role, 'member');
    expect(currentAdmin.loginId, 'admin_naokist');
    expect(currentAdmin.role, 'admin');
  });
}
