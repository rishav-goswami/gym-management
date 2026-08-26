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
            const SizedBox(height: 32),
            const _SaasPlansSection(),
            const SizedBox(height: 32),
            const _UpgradeRequestsSection(),
          ],
        );
      },
    ),
  );
}

class _SaasPlansSection extends StatelessWidget {
  const _SaasPlansSection();

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('saas_plans').snapshots(),
    builder: (context, snapshot) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          children: [
            Text(
              'SaaS plans',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FilledButton.tonalIcon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _PlanDialog(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add plan'),
            ),
          ],
        ),
        const Text(
          'Limits are versioned. Existing gyms keep their accepted plan snapshot.',
        ),
        const SizedBox(height: 12),
        ...?snapshot.data?.docs.map((doc) {
          final plan = doc.data();
          final limits = Map<String, dynamic>.from(
            plan['limits'] as Map? ?? const {},
          );
          return Card(
            child: ListTile(
              title: Text(
                '${plan['name'] ?? doc.id} · v${plan['version'] ?? 1}',
              ),
              subtitle: Text(
                'Members ${limits['activeMembers'] ?? 0} · Trainers ${limits['activeTrainers'] ?? 0} · ₹${((plan['priceMinor'] as num? ?? 0) / 100).toStringAsFixed(0)}',
              ),
              trailing: IconButton(
                tooltip: 'Edit plan',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _PlanDialog(id: doc.id, data: plan),
                ),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          );
        }),
      ],
    ),
  );
}

class _PlanDialog extends StatefulWidget {
  const _PlanDialog({this.id, this.data});
  final String? id;
  final Map<String, dynamic>? data;

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late final id = TextEditingController(text: widget.id ?? '');
  late final name = TextEditingController(
    text: widget.data?['name'] as String? ?? '',
  );
  late final price = TextEditingController(
    text: '${((widget.data?['priceMinor'] as num? ?? 0) / 100).round()}',
  );
  late final members = TextEditingController(
    text: '${_limits['activeMembers'] ?? 100}',
  );
  late final trainers = TextEditingController(
    text: '${_limits['activeTrainers'] ?? 5}',
  );
  late final staff = TextEditingController(
    text: '${_limits['activeStaff'] ?? 5}',
  );
  late final classes = TextEditingController(
    text: '${_limits['scheduledClasses'] ?? 100}',
  );
  Map<String, dynamic> get _limits =>
      Map<String, dynamic>.from(widget.data?['limits'] as Map? ?? const {});
  bool saving = false;

  @override
  void dispose() {
    for (final controller in [
      id,
      name,
      price,
      members,
      trainers,
      staff,
      classes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.id == null ? 'Create SaaS plan' : 'Update SaaS plan'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: id,
              enabled: widget.id == null,
              decoration: const InputDecoration(
                labelText: 'Plan ID (lowercase)',
              ),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monthly price ₹'),
            ),
            TextField(
              controller: members,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Active members'),
            ),
            TextField(
              controller: trainers,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Active trainers'),
            ),
            TextField(
              controller: staff,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Active staff'),
            ),
            TextField(
              controller: classes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Scheduled classes'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Saving…' : 'Save version'),
      ),
    ],
  );

  Future<void> _save() async {
    setState(() => saving = true);
    final isTrial = id.text.trim() == 'trial';
    final ok = await _call(context, 'upsertSaasPlan', {
      'planId': id.text.trim(),
      'name': name.text.trim(),
      'description': '',
      'status': 'active',
      'isPublic': true,
      'isTrial': isTrial,
      'trialDays': 14,
      'currency': 'INR',
      'priceMinor': int.parse(price.text) * 100,
      'billingPeriod': isTrial ? 'trial' : 'monthly',
      'limits': {
        'activeMembers': int.parse(members.text),
        'activeTrainers': int.parse(trainers.text),
        'activeStaff': int.parse(staff.text),
        'scheduledClasses': int.parse(classes.text),
      },
      'features': {
        'classes': true,
        'chat': true,
        'attendanceQr': true,
        'dietPlans': true,
        'progressPhotos': !isTrial,
      },
    });
    if (mounted && ok) Navigator.pop(context);
    if (mounted && !ok) setState(() => saving = false);
  }
}

class _UpgradeRequestsSection extends StatelessWidget {
  const _UpgradeRequestsSection();

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('platform_upgrade_requests')
        .where('status', isEqualTo: 'pending')
        .limit(50)
        .snapshots(),
    builder: (context, snapshot) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending upgrades',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (snapshot.hasData && snapshot.data!.docs.isEmpty)
          const Text('No upgrade requests.'),
        ...?snapshot.data?.docs.map((doc) {
          final data = doc.data();
          return Card(
            child: ListTile(
              title: Text(
                '${data['gymName'] ?? doc.id} → ${data['requestedPlanName'] ?? data['requestedPlanId']}',
              ),
              subtitle: Text(data['note'] as String? ?? ''),
              trailing: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _review(context, doc.id, 'rejected'),
                    child: const Text('Reject'),
                  ),
                  FilledButton(
                    onPressed: () => _review(context, doc.id, 'approved'),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    ),
  );

  Future<void> _review(
    BuildContext context,
    String gymId,
    String decision,
  ) async {
    await _call(context, 'reviewPlatformUpgrade', {
      'gymId': gymId,
      'decision': decision,
    });
  }
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
