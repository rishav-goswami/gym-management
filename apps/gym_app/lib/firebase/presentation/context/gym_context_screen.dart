import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/invitations/gym_invitation_link.dart';
import '../../data/firebase_session_repository.dart';
import '../../logic/session_cubit.dart';

class GymContextScreen extends StatefulWidget {
  const GymContextScreen({super.key, this.invitation});

  final GymInvitationLink? invitation;

  @override
  State<GymContextScreen> createState() => _GymContextScreenState();
}

class _GymContextScreenState extends State<GymContextScreen> {
  late final TextEditingController _gymId;
  late final TextEditingController _token;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _gymId = TextEditingController(text: widget.invitation?.gymId);
    _token = TextEditingController(text: widget.invitation?.token);
  }

  @override
  void dispose() {
    _gymId.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionCubit>().state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose workspace'),
        actions: [
          IconButton(
            onPressed: context.read<SessionCubit>().signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Where are you working?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your permissions are loaded from the selected gym membership.',
          ),
          const SizedBox(height: 20),
          ...state.memberships.map(
            (membership) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    membership.gymName.characters.first.toUpperCase(),
                  ),
                ),
                title: Text(membership.gymName),
                subtitle: Text(membership.role.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.read<SessionCubit>().selectMembership(membership),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (widget.invitation != null) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      'Join ${widget.invitation!.gymName}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You were invited as a ${widget.invitation!.roleLabel}.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _accepting ? null : _accept,
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text(
                        _accepting ? 'Joining…' : 'Accept and join gym',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The signed-in email must match the invitation.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Own a gym?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Create a secure workspace and start a limited free trial.',
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/start-gym'),
                    icon: const Icon(Icons.add_business),
                    label: const Text('Start my gym'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.invitation == null)
            ExpansionTile(
              title: const Text('Accept a gym invitation'),
              subtitle: const Text(
                'Use the gym ID and private token from your invitation.',
              ),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _gymId,
                  decoration: const InputDecoration(labelText: 'Gym ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _token,
                  decoration: const InputDecoration(
                    labelText: 'Invitation token',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _accepting ? null : _accept,
                  child: Text(_accepting ? 'Accepting…' : 'Accept invitation'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await context.read<FirebaseSessionRepository>().acceptInvitation(
        gymId: _gymId.text,
        token: _token.text,
      );
      if (!mounted) return;
      final session = context.read<SessionCubit>();
      await session.refreshContexts();
      for (final membership in session.state.memberships) {
        if (membership.gymId == _gymId.text.trim()) {
          await session.selectMembership(membership);
          if (mounted) context.go('/workspace');
          return;
        }
      }
      if (mounted) context.go('/contexts');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }
}
