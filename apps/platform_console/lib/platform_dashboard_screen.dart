import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PlatformDashboardScreen extends StatelessWidget {
  const PlatformDashboardScreen({required this.onSignOut, super.key});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Gym Management Platform'),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: Text(FirebaseAuth.instance.currentUser?.email ?? ''),
          ),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: onSignOut,
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
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ConsoleError(message: '${snapshot.error}');
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gym tenants',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Text('Platform control plane · latest 50 tenants'),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const _ProvisionGymDialog(),
                  ),
                  icon: const Icon(Icons.add_business),
                  label: const Text('Provision gym'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator(),
            if (snapshot.hasData && snapshot.data!.docs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No gyms have been provisioned yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ...?snapshot.data?.docs.map(
              (document) => _GymTenantCard(document: document),
            ),
          ],
        );
      },
    ),
  );
}

class _GymTenantCard extends StatelessWidget {
  const _GymTenantCard({required this.document});

  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  @override
  Widget build(BuildContext context) {
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
          onSelected: (status) => _call(context, 'updateGymStatus', {
            'gymId': document.id,
            'status': status,
          }),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'trial', child: Text('Trial')),
            PopupMenuItem(value: 'active', child: Text('Active')),
            PopupMenuItem(value: 'suspended', child: Text('Suspended')),
          ],
        ),
      ),
    );
  }
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
  void dispose() {
    name.dispose();
    ownerUid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Provision gym'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Gym name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ownerUid,
            decoration: const InputDecoration(labelText: 'Owner Firebase UID'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Creating…' : 'Create trial'),
      ),
    ],
  );

  Future<void> _save() async {
    if (name.text.trim().isEmpty || ownerUid.text.trim().isEmpty) return;
    setState(() => saving = true);
    final succeeded = await _call(context, 'provisionGym', {
      'name': name.text.trim(),
      'ownerUid': ownerUid.text.trim(),
    });
    if (mounted && succeeded) Navigator.pop(context);
    if (mounted && !succeeded) setState(() => saving = false);
  }
}

Future<bool> _call(
  BuildContext context,
  String function,
  Map<String, dynamic> data,
) async {
  try {
    await FirebaseFunctions.instanceFor(
      region: 'asia-south1',
    ).httpsCallable(function).call<void>(data);
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Operation failed: $error')));
    }
    return false;
  }
}

class _ConsoleError extends StatelessWidget {
  const _ConsoleError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text('Unable to load tenants. $message'),
    ),
  );
}
