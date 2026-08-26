import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_console/platform_login_screen.dart';

void main() {
  testWidgets('platform login validates credentials and has no registration', (
    tester,
  ) async {
    String? submittedEmail;
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformLoginScreen(
          onSignIn: (email, _) async => submittedEmail = email,
        ),
      ),
    );

    expect(find.text('Platform Console'), findsOneWidget);
    expect(find.textContaining('no public registration'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('platformEmail')),
      'admin@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('platformPassword')),
      'password123',
    );
    await tester.tap(find.text('Sign in securely'));
    await tester.pump();
    expect(submittedEmail, 'admin@example.com');
  });
}
