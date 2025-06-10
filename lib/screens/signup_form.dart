import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSignupPressed() {
    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        confirmPassword: _confirmPasswordController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_1, size: 48, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 16),
            Text("Create Account", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28)),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Name",
                prefixIcon: Icon(Icons.person_2_outlined, color: Theme.of(context).colorScheme.secondary),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).colorScheme.secondary),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.secondary),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: "Confirm Password",
                prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.secondary),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                ),
                onPressed: state is AuthLoading ? null : _onSignupPressed,
                child: state is AuthLoading
                    ? const CircularProgressIndicator.adaptive()
                    : const Text("Create Account", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        );
      },
    );
  }
}
