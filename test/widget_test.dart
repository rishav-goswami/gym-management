import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fit_and_fine/presentation/splash/splash_screen.dart';

void main() {
  testWidgets('splash screen shows the product branding', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('PowerUp Fitness'), findsOneWidget);
    expect(find.text('Train. Track. Transform.'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
