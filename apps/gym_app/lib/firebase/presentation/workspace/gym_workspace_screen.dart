import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../data/gym_repository.dart';
import '../../data/gym_media_repository.dart';
import '../../data/firebase_session_repository.dart';
import 'package:gym_core/gym_core.dart';
import '../../logic/session_cubit.dart';
import 'billing_management_panel.dart';
import 'member_billing_panel.dart';
import 'platform_plan_banner.dart';

class GymWorkspaceScreen extends StatefulWidget {
  const GymWorkspaceScreen({super.key});

  @override
  State<GymWorkspaceScreen> createState() => _GymWorkspaceScreenState();
}

class _GymWorkspaceScreenState extends State<GymWorkspaceScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final membership = context.watch<SessionCubit>().state.activeMembership!;
    final destinations = _destinations(membership);
    if (_index >= destinations.length) _index = 0;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final content = _WorkspaceContent(
      destination: destinations[_index],
      membership: membership,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(membership.gymName),
        actions: [
          Chip(label: Text(membership.role.name)),
          IconButton(
            tooltip: 'Switch gym or role',
            onPressed: () =>
                context.read<SessionCubit>().chooseAnotherContext(),
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: context.read<SessionCubit>().signOut,
            icon: const Icon(Icons.logout),
          ),
          PopupMenuButton<String>(
            tooltip: 'Privacy and account',
            onSelected: _accountAction,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Export my data')),
              PopupMenuItem(value: 'delete', child: Text('Delete my account')),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1180,
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: destinations
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
          Expanded(child: content),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index < 4 ? _index : 4,
              onDestinationSelected: (value) =>
                  _selectMobile(value, destinations),
              destinations: [
                ...destinations
                    .take(4)
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.label,
                      ),
                    ),
                const NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            ),
    );
  }

  List<_Destination> _destinations(GymMembership membership) {
    final role = membership.role;
    if (role == GymRole.member) {
      return [
        const _Destination('Home', Icons.home_outlined, 'dashboard'),
        const _Destination(
          'Workout',
          Icons.fitness_center,
          'workout_assignments',
        ),
        const _Destination('Progress', Icons.insights, 'measurements'),
        const _Destination(
          'Membership',
          Icons.card_membership_outlined,
          'billing',
        ),
        if (AppFeatureFlags.attendanceQr && membership.feature('attendanceQr'))
          const _Destination('Check in', Icons.qr_code_scanner, 'attendance'),
        if (membership.feature('classes'))
          const _Destination(
            'Classes',
            Icons.event_available,
            'class_sessions',
          ),
        if (AppFeatureFlags.chat && membership.feature('chat'))
          const _Destination(
            'Support',
            Icons.chat_bubble_outline,
            'conversations',
          ),
      ];
    }
    if (role == GymRole.trainer) {
      return [
        const _Destination('Overview', Icons.dashboard_outlined, 'dashboard'),
        const _Destination('Members', Icons.groups_outlined, 'members'),
        const _Destination(
          'Plans',
          Icons.assignment_outlined,
          'workout_assignments',
        ),
        if (membership.feature('classes'))
          const _Destination(
            'Classes',
            Icons.event_available,
            'class_sessions',
          ),
        if (AppFeatureFlags.chat && membership.feature('chat'))
          const _Destination(
            'Support',
            Icons.chat_bubble_outline,
            'conversations',
          ),
      ];
    }
    return [
      const _Destination('Dashboard', Icons.dashboard_outlined, 'dashboard'),
      const _Destination('Members', Icons.groups_outlined, 'members'),
      if (AppFeatureFlags.attendanceQr && membership.feature('attendanceQr'))
        const _Destination('Attendance', Icons.qr_code_scanner, 'attendance'),
      if (membership.feature('classes'))
        const _Destination('Classes', Icons.event_available, 'class_sessions'),
      const _Destination('Payments', Icons.payments_outlined, 'payments'),
      const _Destination('Staff', Icons.badge_outlined, 'staff'),
      const _Destination('Notices', Icons.campaign_outlined, 'announcements'),
      const _Destination('Settings', Icons.settings_outlined, 'configuration'),
    ];
  }

  Future<void> _selectMobile(int value, List<_Destination> destinations) async {
    if (value < 4) {
      setState(() => _index = value);
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var index = 4; index < destinations.length; index++)
              ListTile(
                leading: Icon(destinations[index].icon),
                title: Text(destinations[index].label),
                selected: _index == index,
                onTap: () => Navigator.pop(context, index),
              ),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _index = selected);
  }

  Future<void> _accountAction(String action) async {
    final repository = context.read<FirebaseSessionRepository>();
    if (action == 'export') {
      try {
        final data = await repository.exportMyData();
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                Uint8List.fromList(utf8.encode(jsonEncode(data))),
                mimeType: 'application/json',
                name: 'fitlife-account-export.json',
              ),
            ],
            subject: 'My Gym Management account export',
          ),
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$error')));
        }
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'Your account will be disabled now and scheduled for deletion after 30 days.',
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
    if (confirmed == true) {
      await repository.requestAccountDeletion();
      if (mounted) {
        await context.read<SessionCubit>().signOut();
      }
    }
  }
}

class _WorkspaceContent extends StatelessWidget {
  const _WorkspaceContent({
    required this.destination,
    required this.membership,
  });
  final _Destination destination;
  final GymMembership membership;

  @override
  Widget build(BuildContext context) {
    if (destination.collection == 'dashboard') {
      return _Dashboard(membership: membership);
    }
    if (destination.collection == 'attendance') {
      return _AttendancePanel(membership: membership);
    }
    if (destination.collection == 'class_sessions') {
      return _ClassesPanel(membership: membership);
    }
    if (destination.collection == 'configuration') {
      return _GymSettingsPanel(membership: membership);
    }
    if (destination.collection == 'payments') {
      return BillingManagementPanel(membership: membership);
    }
    if (destination.collection == 'billing') {
      return MemberBillingPanel(membership: membership);
    }
    if (destination.collection == 'conversations') {
      return _ConversationsPanel(membership: membership);
    }
    return _CollectionView(destination: destination, membership: membership);
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.membership});
  final GymMembership membership;

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>>(
    stream: context.read<GymRepository>().dashboard(membership.gymId),
    builder: (context, snapshot) {
      final metrics = snapshot.data ?? const {};
      final cards = <(String, Object, IconData)>[
        ('Active members', metrics['activeMembers'] ?? '—', Icons.groups),
        ('Expiring soon', metrics['expiringSoon'] ?? '—', Icons.timer_outlined),
        (
          'Today check-ins',
          metrics['todayAttendance'] ?? '—',
          Icons.how_to_reg,
        ),
        (
          'Revenue this month',
          metrics['monthlyRevenueMinor'] == null
              ? '—'
              : '₹${(metrics['monthlyRevenueMinor'] as num) / 100}',
          Icons.currency_rupee,
        ),
      ];
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Good to see you',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text('Live operational summary for ${membership.gymName}'),
          if (membership.role == GymRole.owner ||
              membership.role == GymRole.manager) ...[
            const SizedBox(height: 12),
            PlatformPlanBanner(membership: membership),
          ],
          if (membership.role == GymRole.member) ...[
            const SizedBox(height: 16),
            MemberSubscriptionBanner(membership: membership),
          ],
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width > 900 ? 4 : 2,
              childAspectRatio: 1.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(cards[index].$3),
                    const Spacer(),
                    Text(
                      '${cards[index].$2}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(cards[index].$1),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Card(
            child: ListTile(
              leading: Icon(Icons.cloud_done),
              title: Text('Firebase workspace connected'),
              subtitle: Text(
                'High-volume history is paginated; only operational views update live.',
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _CollectionView extends StatelessWidget {
  const _CollectionView({required this.destination, required this.membership});
  final _Destination destination;
  final GymMembership membership;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          destination.label,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if ((destination.collection == 'members' &&
                membership.can('members.write')) ||
            (destination.collection == 'staff' &&
                membership.can('staff.manage')))
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _showInvitation(context),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Invite'),
            ),
          ),
        if (destination.collection == 'members' &&
            membership.can('members.read'))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _export(context, 'members'),
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
            ),
          ),
        if (destination.collection == 'workout_assignments' &&
            membership.can('fitness.manage'))
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _showWorkoutAssignment(context),
              icon: const Icon(Icons.assignment_add),
              label: const Text('Assign workout'),
            ),
          ),
        if (destination.collection == 'measurements' &&
            membership.role == GymRole.member)
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              if (AppFeatureFlags.progressPhotos &&
                  membership.feature('progressPhotos'))
                OutlinedButton.icon(
                  onPressed: () => _uploadProgressPhoto(context),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Progress photo'),
                ),
              FilledButton.icon(
                onPressed: () => _showMeasurement(context),
                icon: const Icon(Icons.add_chart),
                label: const Text('Log measurement'),
              ),
            ],
          ),
        if (destination.collection == 'announcements' &&
            membership.can('announcements.manage'))
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _showAnnouncement(context),
              icon: const Icon(Icons.campaign),
              label: const Text('Publish notice'),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Showing the 30 newest records. Additional pages load on demand in full workflows.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream(context),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Unable to load: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No records yet'));
              }
              return ListView.separated(
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final document = snapshot.data!.docs[index];
                  final data = document.data();
                  final title =
                      data['name'] ??
                      data['title'] ??
                      data['displayName'] ??
                      data['memberName'] ??
                      document.id;
                  final status =
                      data['status'] ?? data['role'] ?? data['method'] ?? '';
                  return ListTile(
                    title: Text('$title'),
                    subtitle: status == '' ? null : Text('$status'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _canEditMembership
                        ? () => _editMembership(context, document.id, data)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream(BuildContext context) {
    const memberOwned = {
      'workout_assignments',
      'diet_assignments',
      'goals',
      'measurements',
      'personal_records',
      'workout_logs',
    };
    final repository = context.read<GymRepository>();
    if (membership.role == GymRole.member &&
        memberOwned.contains(destination.collection)) {
      return repository.recentForMember(
        membership.gymId,
        destination.collection,
        membership.uid,
      );
    }
    return repository.recent(membership.gymId, destination.collection);
  }

  bool get _canEditMembership =>
      (destination.collection == 'members' &&
          membership.can('members.write')) ||
      (destination.collection == 'staff' && membership.can('staff.manage'));

  Future<void> _editMembership(
    BuildContext context,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final uid = data['uid'] as String? ?? documentId;
    var role =
        data['role'] as String? ??
        (destination.collection == 'members' ? 'member' : 'trainer');
    var status = data['status'] as String? ?? 'active';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Update ${data['displayName'] ?? uid}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (destination.collection == 'staff')
                DropdownButtonFormField<String>(
                  initialValue: role,
                  items:
                      const ['manager', 'receptionist', 'trainer', 'accountant']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setDialogState(() => role = value!),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              DropdownButtonFormField<String>(
                initialValue: status,
                items: const ['active', 'inactive']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => status = value!),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
            ],
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
    if (accepted != true || !context.mounted) return;
    try {
      await context.read<GymRepository>().updateMembership(
        gymId: membership.gymId,
        uid: uid,
        role: destination.collection == 'members' ? 'member' : role,
        status: status,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _showInvitation(BuildContext context) async {
    final email = TextEditingController();
    var role = destination.collection == 'members' ? 'member' : 'trainer';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create invitation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              if (destination.collection == 'staff')
                DropdownButtonFormField<String>(
                  initialValue: role,
                  items:
                      const ['manager', 'receptionist', 'trainer', 'accountant']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setDialogState(() => role = value!),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !context.mounted) return;
    try {
      final response = await context.read<GymRepository>().createInvitation(
        gymId: membership.gymId,
        role: role,
        email: email.text.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation token: ${response['token']}')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _export(BuildContext context, String collection) async {
    try {
      final content = await context.read<GymRepository>().exportCsv(
        gymId: membership.gymId,
        collection: collection,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(content)),
              mimeType: 'text/csv',
              name: '${membership.gymId}-$collection.csv',
            ),
          ],
          subject: '${membership.gymName} $collection report',
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _showWorkoutAssignment(BuildContext context) async {
    final memberUid = TextEditingController();
    final title = TextEditingController();
    final routine = TextEditingController();
    final accepted = await _textRecordDialog(
      context,
      title: 'Assign workout',
      fields: [
        (memberUid, 'Member UID'),
        (title, 'Plan title'),
        (routine, 'Routine and trainer notes'),
      ],
    );
    if (!accepted || !context.mounted) return;
    try {
      await context.read<GymRepository>().createManagedRecord(
        gymId: membership.gymId,
        collection: 'workout_assignments',
        data: {
          'memberUid': memberUid.text.trim(),
          'trainerUid': membership.uid,
          'title': title.text.trim(),
          'routine': routine.text.trim(),
          'revision': 1,
          'status': 'active',
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Workout assigned.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _showMeasurement(BuildContext context) async {
    final weight = TextEditingController();
    final bodyFat = TextEditingController();
    final accepted = await _textRecordDialog(
      context,
      title: 'Log body measurement',
      fields: [(weight, 'Weight (kg)'), (bodyFat, 'Body fat % (optional)')],
      numeric: true,
    );
    if (!accepted || !context.mounted) return;
    try {
      await context.read<GymRepository>().saveMemberOwnedRecord(
        gymId: membership.gymId,
        collection: 'measurements',
        uid: membership.uid,
        data: {
          'weightKg': double.parse(weight.text),
          if (bodyFat.text.trim().isNotEmpty)
            'bodyFatPercent': double.parse(bodyFat.text),
          'measuredAt': Timestamp.now(),
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Measurement saved.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _uploadProgressPhoto(BuildContext context) async {
    try {
      final path = await context
          .read<GymMediaRepository>()
          .pickAndUploadProgressPhoto(
            gymId: membership.gymId,
            uid: membership.uid,
          );
      if (context.mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Private progress photo uploaded.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _showAnnouncement(BuildContext context) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final accepted = await _textRecordDialog(
      context,
      title: 'Publish notice',
      fields: [(title, 'Title'), (body, 'Message')],
    );
    if (!accepted || !context.mounted) return;
    await context.read<GymRepository>().createManagedRecord(
      gymId: membership.gymId,
      collection: 'announcements',
      data: {
        'title': title.text.trim(),
        'body': body.text.trim(),
        'publishedBy': membership.uid,
        'status': 'published',
      },
    );
  }

  Future<bool> _textRecordDialog(
    BuildContext context, {
    required String title,
    required List<(TextEditingController, String)> fields,
    bool numeric = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields
                .map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: field.$1,
                      keyboardType: numeric
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      decoration: InputDecoration(labelText: field.$2),
                    ),
                  ),
                )
                .toList(),
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
      ) ??
      false;
}

class _AttendancePanel extends StatefulWidget {
  const _AttendancePanel({required this.membership});
  final GymMembership membership;

  @override
  State<_AttendancePanel> createState() => _AttendancePanelState();
}

class _AttendancePanelState extends State<_AttendancePanel> {
  Map<String, dynamic>? qr;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final canManage = widget.membership.can('attendance.manage');
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Attendance', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          canManage
              ? 'Generate a short-lived check-in code for the front desk.'
              : 'Scan the rotating gym code. Duplicate daily check-ins are rejected.',
        ),
        const SizedBox(height: 24),
        if (canManage) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : _generate,
                icon: const Icon(Icons.qr_code),
                label: const Text('Generate 60-second QR'),
              ),
              OutlinedButton.icon(
                onPressed: _exportAttendance,
                icon: const Icon(Icons.download),
                label: const Text('Export attendance'),
              ),
            ],
          ),
          if (qr != null) ...[
            const SizedBox(height: 24),
            Center(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.white),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: QrImageView(
                    data: '${widget.membership.gymId}|${qr!['token']}',
                    size: 260,
                  ),
                ),
              ),
            ),
            const Center(child: Text('Refresh after 60 seconds')),
          ],
        ] else
          FilledButton.icon(
            onPressed: busy ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan check-in QR'),
          ),
      ],
    );
  }

  Future<void> _generate() async {
    setState(() => busy = true);
    try {
      final value = await context.read<GymRepository>().createAttendanceQr(
        widget.membership.gymId,
      );
      if (mounted) setState(() => qr = value);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _scan() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => const _QrScannerDialog(),
    );
    if (value == null || !mounted) return;
    final parts = value.split('|');
    if (parts.length != 2 || parts.first != widget.membership.gymId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This QR belongs to another gym.')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await context.read<GymRepository>().checkIn(
        gymId: widget.membership.gymId,
        token: parts.last,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked in successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _exportAttendance() async {
    try {
      final content = await context.read<GymRepository>().exportCsv(
        gymId: widget.membership.gymId,
        collection: 'attendance',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(content)),
              mimeType: 'text/csv',
              name: '${widget.membership.gymId}-attendance.csv',
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class _QrScannerDialog extends StatefulWidget {
  const _QrScannerDialog();

  @override
  State<_QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<_QrScannerDialog> {
  bool found = false;

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 420,
      height: 520,
      child: Column(
        children: [
          const ListTile(title: Text('Scan attendance QR')),
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                final value = capture.barcodes.firstOrNull?.rawValue;
                if (!found && value != null) {
                  found = true;
                  Navigator.pop(context, value);
                }
              },
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}

class _ClassesPanel extends StatelessWidget {
  const _ClassesPanel({required this.membership});
  final GymMembership membership;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Classes',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            if (membership.can('classes.manage'))
              FilledButton.icon(
                onPressed: () => _createClass(context),
                icon: const Icon(Icons.add),
                label: const Text('Schedule'),
              ),
          ],
        ),
        const Text(
          'Bookings are atomic, so the final space cannot be oversold.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: context.read<GymRepository>().recent(
              membership.gymId,
              'class_sessions',
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Unable to load: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No classes scheduled'));
              }
              return ListView(
                children: snapshot.data!.docs.map((document) {
                  final data = document.data();
                  return Card(
                    child: ListTile(
                      title: Text(data['name'] as String? ?? 'Class'),
                      subtitle: Text(
                        '${data['bookedCount'] ?? 0}/${data['capacity'] ?? 0} booked',
                      ),
                      trailing: membership.role == GymRole.member
                          ? FilledButton(
                              onPressed: () => _book(context, document.id),
                              child: const Text('Book'),
                            )
                          : Text(data['status'] as String? ?? 'scheduled'),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    ),
  );

  Future<void> _book(BuildContext context, String sessionId) async {
    try {
      await context.read<GymRepository>().bookClass(
        gymId: membership.gymId,
        sessionId: sessionId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Class booked.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _createClass(BuildContext context) async {
    final name = TextEditingController();
    final capacity = TextEditingController(text: '12');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Schedule class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Class name'),
            ),
            TextField(
              controller: capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacity'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    try {
      await context.read<GymRepository>().createClassSession(
        gymId: membership.gymId,
        name: name.text.trim(),
        capacity: int.parse(capacity.text),
        trainerUid: membership.role == GymRole.trainer ? membership.uid : null,
        startsAt: DateTime.now().add(const Duration(days: 1)),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class _ConversationsPanel extends StatelessWidget {
  const _ConversationsPanel({required this.membership});
  final GymMembership membership;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Support conversations',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: () => _start(context),
              icon: const Icon(Icons.add_comment),
              label: const Text('Start'),
            ),
          ],
        ),
        const Text(
          'Direct chat is restricted to an active trainer/member pair.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: context.read<GymRepository>().conversations(
              membership.gymId,
              membership.uid,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No conversations yet'));
              }
              return ListView(
                children: snapshot.data!.docs.map((document) {
                  final data = document.data();
                  final participants = List<String>.from(
                    data['participantUids'] as List? ?? const [],
                  );
                  final other =
                      participants
                          .where((uid) => uid != membership.uid)
                          .firstOrNull ??
                      'Support';
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(other),
                    subtitle: Text(
                      data['lastMessage'] as String? ??
                          'Start the conversation',
                    ),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => _ChatDialog(
                        membership: membership,
                        conversationId: document.id,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    ),
  );

  Future<void> _start(BuildContext context) async {
    final target = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          membership.role == GymRole.member
              ? 'Contact trainer'
              : 'Contact member',
        ),
        content: TextField(
          controller: target,
          decoration: const InputDecoration(labelText: 'Firebase UID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    try {
      final id = await context.read<GymRepository>().createConversation(
        gymId: membership.gymId,
        targetUid: target.text.trim(),
      );
      if (context.mounted) {
        showDialog<void>(
          context: context,
          builder: (_) =>
              _ChatDialog(membership: membership, conversationId: id),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class _ChatDialog extends StatefulWidget {
  const _ChatDialog({required this.membership, required this.conversationId});
  final GymMembership membership;
  final String conversationId;

  @override
  State<_ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<_ChatDialog> {
  final message = TextEditingController();

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 560,
      height: 640,
      child: Column(
        children: [
          ListTile(
            title: const Text('Trainer support'),
            trailing: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: context.read<GymRepository>().messages(
                widget.membership.gymId,
                widget.conversationId,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  children: snapshot.data!.docs.map((document) {
                    final data = document.data();
                    final mine = data['senderUid'] == widget.membership.uid;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(data['text'] as String? ?? 'Attachment'),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: message,
                    decoration: const InputDecoration(hintText: 'Message'),
                  ),
                ),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _send() async {
    final text = message.text.trim();
    if (text.isEmpty) return;
    message.clear();
    await context.read<GymRepository>().sendMessage(
      gymId: widget.membership.gymId,
      conversationId: widget.conversationId,
      senderUid: widget.membership.uid,
      text: text,
    );
  }
}

class _GymSettingsPanel extends StatefulWidget {
  const _GymSettingsPanel({required this.membership});
  final GymMembership membership;

  @override
  State<_GymSettingsPanel> createState() => _GymSettingsPanelState();
}

class _GymSettingsPanelState extends State<_GymSettingsPanel> {
  late final name = TextEditingController(text: widget.membership.gymName);
  final currency = TextEditingController(text: 'INR');
  final timezone = TextEditingController(text: 'Asia/Kolkata');
  final locale = TextEditingController(text: 'en-IN');
  late final primaryColor = TextEditingController(
    text: widget.membership.primaryColor,
  );
  late final features = <String, bool>{
    'classes': widget.membership.feature('classes'),
    'chat': widget.membership.feature('chat'),
    'attendanceQr': widget.membership.feature('attendanceQr'),
    'dietPlans': widget.membership.feature('dietPlans'),
    'progressPhotos': widget.membership.feature('progressPhotos'),
  };
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    currency.dispose();
    timezone.dispose();
    locale.dispose();
    primaryColor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('Gym settings', style: Theme.of(context).textTheme.headlineMedium),
      const Text(
        'Branding and regional settings update at runtime for the shared app.',
      ),
      const SizedBox(height: 20),
      TextField(
        controller: name,
        decoration: const InputDecoration(labelText: 'Gym name'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: primaryColor,
        decoration: const InputDecoration(labelText: 'Primary color (#RRGGBB)'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: currency,
        decoration: const InputDecoration(labelText: 'Currency'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: timezone,
        decoration: const InputDecoration(labelText: 'IANA timezone'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: locale,
        decoration: const InputDecoration(labelText: 'Locale'),
      ),
      const SizedBox(height: 16),
      Text('Features', style: Theme.of(context).textTheme.titleMedium),
      ...features.entries.map(
        (entry) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(entry.key),
          value: entry.value,
          onChanged: (value) => setState(() => features[entry.key] = value),
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Saving…' : 'Save settings'),
      ),
    ],
  );

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await context.read<GymRepository>().updateConfiguration(
        gymId: widget.membership.gymId,
        name: name.text.trim(),
        currency: currency.text.trim(),
        timezone: timezone.text.trim(),
        locale: locale.text.trim(),
        primaryColor: primaryColor.text.trim(),
        features: features,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved. Switch context to reload branding.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.collection);
  final String label;
  final IconData icon;
  final String collection;
}
