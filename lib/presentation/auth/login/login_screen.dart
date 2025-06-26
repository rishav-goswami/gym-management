// lib/presentation/auth/login/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'login_form.dart';

class LoginScreen extends StatelessWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // const SizedBox(height: 24),
                  // 🧍 SVG Illustration
                  SvgPicture.asset(
                    'assets/images/welcome/login.svg', // Replace with your SVG
                    height: 180,
                  ),

                  const SizedBox(height: 32),

                  // ✨ Welcome Text
                  Text(
                    "Welcome to FitLife",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      // color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Join our community of fitness enthusiasts and\nachieve your goals together.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 36),

                  // 🔒 Login Form
                  const LoginForm(),

                  const SizedBox(height: 16),

                  // 📝 Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go("/signup/$role"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.onPrimary,
                        // foregroundColor: Colors.black87,
                      ),
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 📄 Terms
                  Text(
                    "By continuing, you agree to our Terms of Service and\nPrivacy Policy.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
