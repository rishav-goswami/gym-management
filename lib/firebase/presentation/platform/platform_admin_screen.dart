import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/session_cubit.dart';

class PlatformAdminScreen extends StatelessWidget {
  const PlatformAdminScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Gym Management Platform'),
      actions: [
        IconButton(
          onPressed: context.read<SessionCubit>().chooseAnotherContext,
          icon: const Icon(Icons.swap_horiz),
        ),
        IconButton(
          onPressed: context.read<SessionCubit>().signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('gyms')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gym tenants',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _ProvisionGymDialog(),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Provision gym'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!snapshot.hasData) const LinearProgressIndicator(),
          ...?snapshot.data?.docs.map((document) {
            final gym = document.data();
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
                title: Text(gym['name'] as String? ?? document.id),
                subtitle: Text(
                  '${gym['status'] ?? 'unknown'} · ${gym['platformPlan'] ?? 'manual'}',
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Change tenant status',
                  initialValue: gym['status'] as String?,
                  onSelected: (status) =>
                      FirebaseFunctions.instanceFor(region: 'asia-south1')
                          .httpsCallable('updateGymStatus')
                          .call<void>({'gymId': document.id, 'status': status}),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'trial', child: Text('Trial')),
                    PopupMenuItem(value: 'active', child: Text('Active')),
                    PopupMenuItem(value: 'suspended', child: Text('Suspended')),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

class _ProvisionGymDialog extends StatefulWidget {
  const _ProvisionGymDialog();

  @override
  State<_ProvisionGymDialog> createState() => _ProvisionGymDialogState();
}

class _ProvisionGymDialogState extends State<_ProvisionGymDialog> {
  final name = TextEditingController();
  final ownerUid = TextEditingController();
  bool saving = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Provision gym'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Gym name'),
        ),
        TextField(
          controller: ownerUid,
          decoration: const InputDecoration(labelText: 'Owner Firebase UID'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Creating…' : 'Create trial'),
      ),
    ],
  );

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).httpsCallable('provisionGym').call<void>({
        'name': name.text.trim(),
        'ownerUid': ownerUid.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
      if (mounted) setState(() => saving = false);
    }
  }
}
