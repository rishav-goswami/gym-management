import 'package:gym_management/presentation/auth/login/login_screen.dart';
import 'package:gym_management/presentation/auth/login/login_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin accounts cannot self-register', () {
    expect(LoginScreen.canSelfRegister('ADMIN'), isFalse);
    expect(LoginScreen.canSelfRegister('admin'), isFalse);
  });

  test('member and trainer accounts can self-register', () {
    expect(LoginScreen.canSelfRegister('MEMBER'), isTrue);
    expect(LoginScreen.canSelfRegister('TRAINER'), isTrue);
  });

  test('login accepts longer and local development email domains', () {
    expect(LoginForm.isValidEmail('admin@fitlife.local'), isTrue);
    expect(LoginForm.isValidEmail('member@example.technology'), isTrue);
    expect(LoginForm.isValidEmail('not-an-email'), isFalse);
  });
}
