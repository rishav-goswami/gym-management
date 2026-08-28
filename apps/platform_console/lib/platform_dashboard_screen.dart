import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'platform_insights_panel.dart';
import 'tenant_branding_dialog.dart';
import 'tenant_subscription_dialog.dart';

enum _ConsoleSection {
  overview('Overview', Icons.space_dashboard_outlined),
  gyms('Gyms', Icons.business_outlined),
  plans('Plans & upgrades', Icons.workspace_premium_outlined),
  analytics('Feature analytics', Icons.query_stats_outlined),
  feedback('Feedback', Icons.forum_outlined);

  const _ConsoleSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

class PlatformDashboardScreen extends StatefulWidget {
  const PlatformDashboardScreen({required this.onSignOut, super.key});

  final Future<void> Function() onSignOut;

  @override
  State<PlatformDashboardScreen> createState() =>
      _PlatformDashboardScreenState();
}

class _PlatformDashboardScreenState extends State<PlatformDashboardScreen> {
  _ConsoleSection section = _ConsoleSection.overview;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 980;
      return Scaffold(
        appBar: AppBar(
          title: Text(section.label),
          actions: [
            if (constraints.maxWidth >= 700)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Chip(
                    avatar: const Icon(Icons.admin_panel_settings_outlined),
                    label: Text(
                      FirebaseAuth.instance.currentUser?.email ?? 'Operator',
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        drawer: desktop ? null : Drawer(child: _drawerNavigation()),
        body: Row(
          children: [
            if (desktop) ...[
              NavigationRail(
                extended: true,
                minExtendedWidth: 250,
                selectedIndex: section.index,
                onDestinationSelected: (index) =>
                    setState(() => section = _ConsoleSection.values[index]),
                leading: const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 28),
                  child: _ConsoleBrand(),
                ),
                destinations: [
                  for (final item in _ConsoleSection.values)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.icon, fill: 1),
                      label: Text(item.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
            ],
            Expanded(child: _sectionContent()),
          ],
        ),
      );
    },
  );

  Widget _drawerNavigation() => SafeArea(
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Align(alignment: Alignment.centerLeft, child: _ConsoleBrand()),
        ),
        const Divider(),
        for (final item in _ConsoleSection.values)
          ListTile(
            leading: Icon(item.icon),
            title: Text(item.label),
            selected: section == item,
            onTap: () {
              setState(() => section = item);
              Navigator.pop(context);
            },
          ),
        const Spacer(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: widget.onSignOut,
        ),
      ],
    ),
  );

  Widget _sectionContent() => switch (section) {
    _ConsoleSection.overview => const _ConsolePage(
      title: 'Platform overview',
      description: 'Health, scale and adoption across your gym tenants.',
      child: PlatformInsightsPanel(view: PlatformInsightsView.overview),
    ),
    _ConsoleSection.gyms => const _ConsolePage(
      title: 'Gym tenants',
      description: 'Provision gyms and manage branding, plans and access.',
      child: _GymTenantsSection(),
    ),
    _ConsoleSection.plans => const _ConsolePage(
      title: 'Plans & upgrades',
      description:
          'Version quotas, feature bundles and review upgrade requests.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SaasPlansSection(),
          SizedBox(height: 32),
          _UpgradeRequestsSection(),
        ],
      ),
    ),
    _ConsoleSection.analytics => const _ConsolePage(
      title: 'Feature analytics',
      description: 'Compare feature adoption and relevance by audience role.',
      child: PlatformInsightsPanel(view: PlatformInsightsView.analytics),
    ),
    _ConsoleSection.feedback => const _ConsolePage(
      title: 'Product feedback',
      description: 'Review member, trainer and owner ratings and comments.',
      child: PlatformInsightsPanel(view: PlatformInsightsView.feedback),
    ),
  };
}

class _ConsoleBrand extends StatelessWidget {
  const _ConsoleBrand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.fitness_center),
      ),
      const SizedBox(width: 12),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gym Management', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Platform console', style: TextStyle(fontSize: 12)),
        ],
      ),
    ],
  );
}

class _ConsolePage extends StatelessWidget {
  const _ConsolePage({
    required this.title,
    required this.description,
    required this.child,
  });
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(description, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    ),
  );
}

class _GymTenantsSection extends StatelessWidget {
  const _GymTenantsSection();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('gyms')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ConsoleError(message: '${snapshot.error}');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const _ProvisionGymDialog(),
                  ),
                  icon: const Icon(Icons.add_business),
                  label: const Text('Provision gym'),
                ),
              ),
              const SizedBox(height: 16),
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
  late final Map<String, bool> features = Map<String, bool>.from(
    widget.data?['features'] as Map? ??
        const {
          'classes': true,
          'chat': true,
          'attendanceQr': true,
          'dietPlans': true,
          'progressPhotos': false,
        },
  );

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
            const SizedBox(height: 16),
            Text(
              'Included features',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final entry in const <String, String>{
              'classes': 'Classes and bookings',
              'chat': 'Member–trainer chat',
              'attendanceQr': 'QR attendance',
              'dietPlans': 'Diet plans',
              'progressPhotos': 'Progress photos',
            }.entries)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: features[entry.key] == true,
                onChanged: (value) =>
                    setState(() => features[entry.key] = value),
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
      'features': features,
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .doc('gyms/${document.id}/usage/current')
          .snapshots(),
      builder: (context, snapshot) {
        final usage = snapshot.data?.data() ?? const {};
        final users =
            (usage['activeMembers'] as num? ?? 0) +
            (usage['activeTrainers'] as num? ?? 0) +
            (usage['activeStaff'] as num? ?? 0) +
            1;
        final summary =
            '$users users · ${usage['activeMembers'] ?? 0} members · '
            '${usage['activeTrainers'] ?? 0} trainers · ${usage['activeStaff'] ?? 0} staff';
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              _TenantLogo(gym: gym),
                              const SizedBox(width: 12),
                              Expanded(child: _identity(gym)),
                            ],
                          ),
                          const Divider(height: 24),
                          Text(summary),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, children: _actions(context, gym)),
                        ],
                      )
                    : Row(
                        children: [
                          _TenantLogo(gym: gym),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [_identity(gym), Text(summary)],
                            ),
                          ),
                          Wrap(spacing: 6, children: _actions(context, gym)),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _identity(Map<String, dynamic> gym) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        gym['name'] as String? ?? document.id,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      Text(
        '${gym['status'] ?? 'unknown'} · ${gym['platformPlan'] ?? 'manual'}',
      ),
    ],
  );

  List<Widget> _actions(BuildContext context, Map<String, dynamic> gym) => [
    TextButton.icon(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => TenantBrandingDialog(document: document),
      ),
      icon: const Icon(Icons.palette_outlined),
      label: const Text('Branding'),
    ),
    TextButton.icon(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => TenantSubscriptionDialog(document: document),
      ),
      icon: const Icon(Icons.workspace_premium_outlined),
      label: const Text('Plan'),
    ),
    PopupMenuButton<String>(
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
  ];
}

class _ProvisionGymDialog extends StatefulWidget {
  const _ProvisionGymDialog();

  @override
  State<_ProvisionGymDialog> createState() => _ProvisionGymDialogState();
}

class _ProvisionGymDialogState extends State<_ProvisionGymDialog> {
  final name = TextEditingController();
  final ownerEmail = TextEditingController();
  final city = TextEditingController();
  final phone = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    ownerEmail.dispose();
    city.dispose();
    phone.dispose();
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
            controller: ownerEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Owner account email',
              helperText: 'The owner must register this email first.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: city,
            decoration: const InputDecoration(labelText: 'City (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Business phone (optional)',
            ),
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
    if (name.text.trim().isEmpty || ownerEmail.text.trim().isEmpty) return;
    setState(() => saving = true);
    final succeeded = await _call(context, 'provisionGym', {
      'name': name.text.trim(),
      'ownerEmail': ownerEmail.text.trim().toLowerCase(),
      if (city.text.trim().isNotEmpty) 'city': city.text.trim(),
      if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
    });
    if (mounted && succeeded) Navigator.pop(context);
    if (mounted && !succeeded) setState(() => saving = false);
  }
}

class _TenantLogo extends StatelessWidget {
  const _TenantLogo({required this.gym});

  final Map<String, dynamic> gym;

  @override
  Widget build(BuildContext context) {
    final branding = Map<String, dynamic>.from(
      gym['branding'] as Map? ?? const {},
    );
    final logoUrl = branding['logoUrl'] as String?;
    if (logoUrl == null || logoUrl.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.fitness_center));
    }
    return CircleAvatar(
      backgroundImage: NetworkImage(logoUrl),
      onBackgroundImageError: (_, _) {},
      child: const SizedBox.shrink(),
    );
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
