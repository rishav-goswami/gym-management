import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../data/firebase_session_repository.dart';
import '../../data/gym_repository.dart';
import '../../logic/session_cubit.dart';

class StartGymTrialScreen extends StatefulWidget {
  const StartGymTrialScreen({super.key});

  @override
  State<StartGymTrialScreen> createState() => _StartGymTrialScreenState();
}

class _StartGymTrialScreenState extends State<StartGymTrialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController(text: '+91');
  bool _saving = false;
  bool _verified =
      (FirebaseAuth.instance.currentUser?.emailVerified ?? false) ||
      FirebaseAuth.instance.currentUser?.phoneNumber != null;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Start your gym'),
      leading: BackButton(onPressed: () => context.go('/contexts')),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Run your gym free for 14 days',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'No card required. Your owner role is granted securely after identity verification.',
              ),
              const SizedBox(height: 20),
              const _TrialPlanCard(),
              const SizedBox(height: 20),
              if (!_verified)
                _VerificationCard(onVerified: _refreshVerification),
              if (!_verified) const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Gym name',
                          ),
                          validator: (value) => (value?.trim().length ?? 0) >= 2
                              ? null
                              : 'Enter your gym name',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _city,
                          decoration: const InputDecoration(
                            labelText: 'City (optional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Business phone (optional)',
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: !_verified || _saving ? null : _start,
                          icon: const Icon(Icons.rocket_launch_outlined),
                          label: Text(
                            _saving
                                ? 'Creating secure workspace…'
                                : 'Start free trial',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _refreshVerification() async {
    final verified = await context
        .read<FirebaseSessionRepository>()
        .reloadEmailVerification();
    if (mounted) setState(() => _verified = verified);
    if (!verified && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email is not verified yet. Open the link, then try again.',
          ),
        ),
      );
    }
  }

  Future<void> _start() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    try {
      await context.read<GymRepository>().startGymTrial(
        name: _name.text,
        city: _city.text,
        phone: _phone.text == '+91' ? null : _phone.text,
      );
      if (!mounted) return;
      await context.read<SessionCubit>().refreshContexts();
    } on FirebaseFunctionsException catch (error) {
      if (mounted) _show(error.message ?? 'Unable to start the trial.');
    } catch (error) {
      if (mounted) _show('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _VerificationCard extends StatefulWidget {
  const _VerificationCard({required this.onVerified});
  final Future<void> Function() onVerified;

  @override
  State<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<_VerificationCard> {
  bool sending = false;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verify your identity',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'We sent a verification link to ${FirebaseAuth.instance.currentUser?.email ?? 'your email'}.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              OutlinedButton(
                onPressed: sending
                    ? null
                    : () async {
                        setState(() => sending = true);
                        await context
                            .read<FirebaseSessionRepository>()
                            .sendEmailVerification();
                        if (mounted) setState(() => sending = false);
                      },
                child: const Text('Resend email'),
              ),
              FilledButton.tonal(
                onPressed: widget.onVerified,
                child: const Text("I've verified"),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TrialPlanCard extends StatelessWidget {
  const _TrialPlanCard();

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: context.read<GymRepository>().publicSaasPlans(),
    builder: (context, snapshot) {
      QueryDocumentSnapshot<Map<String, dynamic>>? trial;
      for (final doc
          in snapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
        if (doc.id == 'trial') trial = doc;
      }
      final limits = Map<String, dynamic>.from(
        trial?.data()['limits'] as Map? ?? const {},
      );
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _Limit(label: 'Members', value: limits['activeMembers'] ?? 5),
              _Limit(label: 'Trainers', value: limits['activeTrainers'] ?? 1),
              _Limit(label: 'Staff', value: limits['activeStaff'] ?? 1),
              _Limit(label: 'Classes', value: limits['scheduledClasses'] ?? 3),
            ],
          ),
        ),
      );
    },
  );
}

class _Limit extends StatelessWidget {
  const _Limit({required this.label, required this.value});
  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$value', style: Theme.of(context).textTheme.titleLarge),
      Text(label),
    ],
  );
}
