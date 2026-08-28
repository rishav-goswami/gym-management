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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
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
          child: Form(
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
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: _required,
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
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    if (_key.currentState?.validate() == true) {
                      context.read<SessionCubit>().register(
                        _name.text,
                        _email.text,
                        _password.text,
                      );
                    }
                  },
                  child: const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}
