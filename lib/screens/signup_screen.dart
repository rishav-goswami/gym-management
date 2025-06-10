// screens/signup_screen.dart
import 'package:flutter/material.dart';
import '../theme.dart';
import 'signup_form.dart';

class SignupScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: Theme.of(context).appBarTheme.elevation,
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            color: Theme.of(context).cardColor,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: const SignupForm(),
            ),
          ),
        ),
      ),
    );
  }
}
