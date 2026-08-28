import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_core/gym_core.dart';

import '../../data/gym_repository.dart';
import '../../data/firebase_session_repository.dart';
import '../../logic/session_cubit.dart';
import 'member_progress_panel.dart';
import 'member_training_panel.dart';

class PersonalWorkspaceScreen extends StatefulWidget {
  const PersonalWorkspaceScreen({super.key});

  @override
  State<PersonalWorkspaceScreen> createState() =>
      _PersonalWorkspaceScreenState();
}

class _PersonalWorkspaceScreenState extends State<PersonalWorkspaceScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    final user = session.user;
    if (user == null) return const SizedBox.shrink();
    final scope = FitnessScope.personal(user.uid);
    final pages = [
      _PersonalHome(scope: scope, onTrain: () => setState(() => _index = 1)),
      MemberTrainingPanel(scope: scope),
      MemberProgressPanel(scope: scope),
      _PersonalProfile(scope: scope),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center),
            SizedBox(width: 10),
            Text('My Fitness'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Badge(child: Icon(Icons.notifications_outlined)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      endDrawer: _PersonalNotifications(scope: scope),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.fitness_center_outlined),
                  selectedIcon: Icon(Icons.fitness_center),
                  label: Text('Training'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: Text('Progress'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fitness_center_outlined),
                  selectedIcon: Icon(Icons.fitness_center),
                  label: 'Training',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Progress',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
    );
  }
}

class _PersonalHome extends StatelessWidget {
  const _PersonalHome({required this.scope, required this.onTrain});

  final FitnessScope scope;
  final VoidCallback onTrain;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: context.read<GymRepository>().fitnessRecords(
      scope,
      'workout_logs',
      limit: 30,
    ),
    builder: (context, snapshot) {
      final workouts = snapshot.data?.docs ?? const [];
      final now = DateTime.now();
      final thisWeek = workouts.where((document) {
        final value = document.data()['completedAt'];
        final date = value is Timestamp ? value.toDate() : null;
        return date != null && now.difference(date).inDays < 7;
      }).length;
      final name =
          context.watch<SessionCubit>().state.account['displayName']
              as String? ??
          'there';
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Ready when you are, ${name.split(' ').first}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          const Text('Small, consistent sessions build lasting progress.'),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bolt, size: 34),
                  const SizedBox(height: 12),
                  Text(
                    'Start today’s workout',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Use a routine, choose a guided goal, or log movements as you go.',
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onTrain,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Go to training'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: '$thisWeek',
                  label: 'Workouts this week',
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: '${workouts.length}',
                  label: 'Total workouts',
                  icon: Icons.emoji_events_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Card(
            child: ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('Your fitness data is private'),
              subtitle: Text(
                'Joining a gym shares nothing until you choose categories to share.',
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label),
        ],
      ),
    ),
  );
}

class _PersonalProfile extends StatelessWidget {
  const _PersonalProfile({required this.scope});
  final FitnessScope scope;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    final user = session.user!;
    final name = session.account['displayName'] as String? ?? 'Fitness member';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundImage: user.photoURL == null
                    ? null
                    : NetworkImage(user.photoURL!),
                child: user.photoURL == null
                    ? Text(
                        name.isEmpty
                            ? '?'
                            : name.characters.first.toUpperCase(),
                        style: Theme.of(context).textTheme.headlineMedium,
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(name, style: Theme.of(context).textTheme.headlineSmall),
              Text(user.email ?? user.phoneNumber ?? ''),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: const Text('My gyms & spaces'),
                subtitle: Text(
                  session.memberships.isEmpty
                      ? 'Connect with a gym when you are ready'
                      : '${session.memberships.length} connected gym${session.memberships.length == 1 ? '' : 's'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/spaces'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Fitness preferences'),
                subtitle: const Text('Goals, experience and equipment'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editPreferences(context),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.workspace_premium_outlined),
                title: Text('My plan'),
                subtitle: Text('Free · Core fitness features included'),
              ),
            ],
          ),
        ),
        if (session.memberships.isNotEmpty) ...[
          const SizedBox(height: 14),
          _GymSharingSection(memberships: session.memberships),
        ],
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Export my data'),
                subtitle: const Text('Request a portable copy of your account'),
                onTap: () => _exportData(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: const Text('Support access history'),
                subtitle: const Text('See audited access to your private data'),
                onTap: () => _showSupportHistory(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Delete account'),
                subtitle: const Text('30-day recovery period'),
                onTap: () => _requestDeletion(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: context.read<SessionCubit>().signOut,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editPreferences(BuildContext context) async {
    final snapshot = await context
        .read<GymRepository>()
        .firestore
        .doc(scope.profilePath)
        .get();
    if (!context.mounted) return;
    final data = snapshot.data() ?? const <String, dynamic>{};
    final days = TextEditingController(
      text: '${data['workoutDaysPerWeek'] ?? 3}',
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fitness preferences'),
        content: TextField(
          controller: days,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Workouts per week'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      await context.read<GymRepository>().updateFitnessProfile(
        scope: scope,
        data: {'workoutDaysPerWeek': int.tryParse(days.text) ?? 3},
      );
    }
    days.dispose();
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final data = await context
          .read<FirebaseSessionRepository>()
          .exportMyData();
      final text = data.toString();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Your portable data export'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(child: SelectableText(text)),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy export'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
      }
    }
  }

  Future<void> _showSupportHistory(BuildContext context) async {
    final uid = context.read<SessionCubit>().state.user!.uid;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Support access history'),
        content: SizedBox(
          width: 560,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users/$uid/support_history')
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              final rows = snapshot.data?.docs ?? const [];
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (rows.isEmpty) {
                return const Text('No support access has occurred.');
              }
              return ListView(
                shrinkWrap: true,
                children: rows
                    .map(
                      (row) => ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: Text(
                          row.data()['reason'] as String? ?? 'Support session',
                        ),
                        subtitle: Text(
                          (row.data()['categories'] as List? ?? const []).join(
                            ', ',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestDeletion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request account deletion?'),
        content: const Text(
          'You will be signed out. Personal data and media are permanently removed after 30 days, and all gym sharing is revoked now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Request deletion'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<FirebaseSessionRepository>().requestAccountDeletion();
    if (context.mounted) await context.read<SessionCubit>().signOut();
  }
}

class _GymSharingSection extends StatelessWidget {
  const _GymSharingSection({required this.memberships});
  final List<GymMembership> memberships;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        const ListTile(
          leading: Icon(Icons.privacy_tip_outlined),
          title: Text('Fitness data sharing'),
          subtitle: Text('Every category starts private and can be revoked.'),
        ),
        const Divider(height: 1),
        for (final membership in memberships)
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: context.read<GymRepository>().gymSharing(
              membership.uid,
              membership.gymId,
            ),
            builder: (context, snapshot) {
              final categories = Map<String, bool>.from(
                snapshot.data?.data()?['categories'] as Map? ?? const {},
              );
              final count = categories.values.where((value) => value).length;
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    membership.gymName.characters.first.toUpperCase(),
                  ),
                ),
                title: Text(membership.gymName),
                subtitle: Text(
                  count == 0 ? 'Nothing shared' : '$count categories shared',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _edit(context, membership, categories),
              );
            },
          ),
      ],
    ),
  );

  Future<void> _edit(
    BuildContext context,
    GymMembership membership,
    Map<String, bool> current,
  ) async {
    final values = <String, bool>{
      'profile': current['profile'] ?? false,
      'goals': current['goals'] ?? false,
      'workoutSummaries': current['workoutSummaries'] ?? false,
      'measurements': current['measurements'] ?? false,
      'progress': current['progress'] ?? false,
    };
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Share with ${membership.gymName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: values.entries
                  .map(
                    (entry) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: entry.value,
                      title: Text(switch (entry.key) {
                        'profile' => 'Profile basics',
                        'goals' => 'Fitness goals',
                        'workoutSummaries' => 'Workout summaries',
                        'measurements' => 'Body measurements',
                        _ => 'Progress records',
                      }),
                      onChanged: (value) =>
                          update(() => values[entry.key] = value),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save == true && context.mounted) {
      await context.read<GymRepository>().updateGymSharing(
        gymId: membership.gymId,
        categories: values,
      );
    }
  }
}

class _PersonalNotifications extends StatelessWidget {
  const _PersonalNotifications({required this.scope});
  final FitnessScope scope;

  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: context.read<GymRepository>().fitnessRecords(
          scope,
          'notifications',
          limit: 30,
        ),
        builder: (context, snapshot) {
          final notifications = snapshot.data?.docs ?? const [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(child: Text('You’re all caught up'))
                    : ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final data = notifications[index].data();
                          return ListTile(
                            leading: const Icon(Icons.notifications_outlined),
                            title: Text(data['title'] as String? ?? 'Update'),
                            subtitle: Text(data['body'] as String? ?? ''),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
