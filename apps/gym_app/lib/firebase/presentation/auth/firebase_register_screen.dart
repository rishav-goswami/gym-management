import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/invitations/gym_invitation_link.dart';
import '../../logic/session_cubit.dart';

class FirebaseRegisterScreen extends StatefulWidget {
  const FirebaseRegisterScreen({super.key, this.invitation});

  final GymInvitationLink? invitation;

  @override
  State<FirebaseRegisterScreen> createState() => _FirebaseRegisterScreenState();
}

class _FirebaseRegisterScreenState extends State<FirebaseRegisterScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(
        onPressed: () =>
            context.go(widget.invitation?.loginLocation ?? '/login'),
      ),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: BlocConsumer<SessionCubit, SessionState>(
            listenWhen: (before, after) => before.message != after.message,
            listener: (context, state) {
              if (state.message != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message!)));
              }
            },
            builder: (context, state) {
              final busy = state.status == SessionStatus.initializing;
              return Form(
                key: _key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create your fitness account',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.invitation == null
                          ? 'Build routines, log workouts and track progress. You can connect a gym later.'
                          : 'Create an account with the email invited to ${widget.invitation!.gymName}. Your invitation will be ready after sign-up.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          value != null && _emailPattern.hasMatch(value.trim())
                          ? null
                          : 'Enter a valid email',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) => (value?.length ?? 0) >= 8
                          ? null
                          : 'Use at least 8 characters',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                      ),
                      validator: (value) => value == _password.text
                          ? null
                          : 'Passwords do not match',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : () => _submit(context),
                      child: busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Create account'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  void _submit(BuildContext context) {
    if (_key.currentState?.validate() == true) {
      context.read<SessionCubit>().register(
        _name.text,
        _email.text,
        _password.text,
      );
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}
