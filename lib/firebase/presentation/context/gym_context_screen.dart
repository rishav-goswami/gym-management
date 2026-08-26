import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/firebase_session_repository.dart';
import '../../logic/session_cubit.dart';

class GymContextScreen extends StatefulWidget {
  const GymContextScreen({super.key});

  @override
  State<GymContextScreen> createState() => _GymContextScreenState();
}

class _GymContextScreenState extends State<GymContextScreen> {
  final _gymId = TextEditingController();
  final _token = TextEditingController();
  bool _accepting = false;

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
          if (state.isPlatformAdmin)
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.admin_panel_settings),
                ),
                title: const Text('Platform administration'),
                subtitle: const Text('Provision and support gym tenants'),
                trailing: const Icon(Icons.chevron_right),
                onTap: context
                    .read<SessionCubit>()
                    .selectPlatformAdministration,
              ),
            ),
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
      await context.read<SessionCubit>().refreshContexts();
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
