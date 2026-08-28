import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/invitations/gym_invitation_link.dart';
import '../../logic/session_cubit.dart';
import '../../data/firebase_session_repository.dart';

class FirebaseLoginScreen extends StatefulWidget {
  const FirebaseLoginScreen({super.key, this.invitation});

  final GymInvitationLink? invitation;

  @override
  State<FirebaseLoginScreen> createState() => _FirebaseLoginScreenState();
}

class _FirebaseLoginScreenState extends State<FirebaseLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController(text: '+91');
  final _otp = TextEditingController();
  bool _hidden = true;
  bool _phoneMode = false;
  bool _sendingCode = false;
  String? _verificationId;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: BlocConsumer<SessionCubit, SessionState>(
                listenWhen: (before, after) => before.message != after.message,
                listener: (context, state) {
                  if (state.message != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(state.message!)));
                  }
                },
                builder: (context, state) => Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 52,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Welcome to Gym Management',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.invitation == null
                            ? 'Sign in once, then choose your gym and role.'
                            : 'Sign in with the email invited to ${widget.invitation!.gymName}.',
                        textAlign: TextAlign.center,
                      ),
                      if (widget.invitation != null) ...[
                        const SizedBox(height: 12),
                        Card(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: ListTile(
                            leading: const Icon(Icons.mark_email_read_outlined),
                            title: Text(
                              'Invitation to ${widget.invitation!.gymName}',
                            ),
                            subtitle: Text(
                              'Role: ${widget.invitation!.roleLabel}',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      if (!_phoneMode)
                        TextFormField(
                          key: const Key('firebaseEmail'),
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) =>
                              value != null &&
                                  RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  ).hasMatch(value.trim())
                              ? null
                              : 'Enter a valid email',
                        ),
                      if (!_phoneMode) const SizedBox(height: 16),
                      if (!_phoneMode)
                        TextFormField(
                          key: const Key('firebasePassword'),
                          controller: _password,
                          obscureText: _hidden,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _hidden = !_hidden),
                              icon: Icon(
                                _hidden
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: (value) => (value?.length ?? 0) >= 6
                              ? null
                              : 'Use at least 6 characters',
                        ),
                      if (_phoneMode)
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            helperText: 'Include country code, for example +91',
                          ),
                          validator: (value) =>
                              (value?.replaceAll(RegExp(r'\D'), '').length ??
                                      0) >=
                                  10
                              ? null
                              : 'Enter a valid phone number',
                        ),
                      if (_phoneMode && _verificationId != null) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _otp,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'One-time code',
                          ),
                          validator: (value) => (value?.length ?? 0) >= 6
                              ? null
                              : 'Enter the 6-digit code',
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: state.status == SessionStatus.initializing
                            ? null
                            : _submit,
                        child: state.status == SessionStatus.initializing
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _phoneMode
                                    ? (_verificationId == null
                                          ? 'Send code'
                                          : 'Verify code')
                                    : 'Sign in',
                              ),
                      ),
                      TextButton(
                        onPressed: _sendingCode
                            ? null
                            : () => setState(() {
                                _phoneMode = !_phoneMode;
                                _verificationId = null;
                              }),
                        child: Text(
                          _phoneMode
                              ? 'Use email and password'
                              : 'Use phone OTP',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => context.go(
                          widget.invitation?.registerLocation ?? '/register',
                        ),
                        child: const Text('Create an account or start a gym'),
                      ),
                      const Text(
                        'Owners can start one verified free trial. Staff and member roles are assigned by secure invitation.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_phoneMode) {
      setState(() => _sendingCode = true);
      try {
        final repository = context.read<FirebaseSessionRepository>();
        if (_verificationId == null) {
          final id = await repository.sendPhoneCode(_phone.text);
          if (mounted && id != null) setState(() => _verificationId = id);
        } else {
          await repository.confirmPhoneCode(_verificationId!, _otp.text);
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$error')));
        }
      } finally {
        if (mounted) setState(() => _sendingCode = false);
      }
      return;
    }
    context.read<SessionCubit>().signIn(_email.text.trim(), _password.text);
  }
}
