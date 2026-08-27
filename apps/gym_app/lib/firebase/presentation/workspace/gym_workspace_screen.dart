import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/invitations/gym_invitation_link.dart';
import '../../data/gym_repository.dart';
import '../../data/gym_media_repository.dart';
import '../../data/firebase_session_repository.dart';
import 'package:gym_core/gym_core.dart';
import '../../logic/session_cubit.dart';
import '../member/member_home_panel.dart';
import '../member/member_profile_panel.dart';
import '../member/member_training_panel.dart';
import '../shared/gym_brand_mark.dart';
import 'billing_management_panel.dart';
import 'member_billing_panel.dart';
import 'platform_plan_banner.dart';

class GymWorkspaceScreen extends StatefulWidget {
  const GymWorkspaceScreen({super.key});

  @override
  State<GymWorkspaceScreen> createState() => _GymWorkspaceScreenState();
}

class _GymWorkspaceScreenState extends State<GymWorkspaceScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
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
      onSwitchContext: () =>
          context.read<SessionCubit>().chooseAnotherContext(),
      onExportData: () => _accountAction('export'),
      onDeleteAccount: () => _accountAction('delete'),
      onSignOut: () => context.read<SessionCubit>().signOut(),
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GymBrandMark(membership: membership),
            const SizedBox(width: 10),
            Flexible(
              child: Text(membership.gymName, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          if (membership.role == GymRole.member)
            _MemberNotificationButton(
              membership: membership,
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            )
          else ...[
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
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete my account'),
                ),
              ],
            ),
          ],
        ],
      ),
      endDrawer: membership.role == GymRole.member
          ? _MemberNotificationDrawer(membership: membership)
          : null,
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1180,
              selectedIndex: _index,
              onDestinationSelected: (value) =>
                  _selectDestination(value, destinations, membership),
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
          'Training',
          Icons.fitness_center,
          'workout_assignments',
        ),
        const _Destination('Progress', Icons.insights, 'measurements'),
        const _Destination('Profile', Icons.person_outline, 'profile'),
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
      if (membership.can('staff.manage'))
        const _Destination('Branding', Icons.palette_outlined, 'configuration'),
    ];
  }

  Future<void> _selectMobile(int value, List<_Destination> destinations) async {
    if (value < 4) {
      final membership = context.read<SessionCubit>().state.activeMembership!;
      _selectDestination(value, destinations, membership);
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
    if (!mounted) return;
    if (selected != null) {
      final membership = context.read<SessionCubit>().state.activeMembership!;
      _selectDestination(selected, destinations, membership);
    }
  }

  void _selectDestination(
    int value,
    List<_Destination> destinations,
    GymMembership membership,
  ) {
    setState(() => _index = value);
    final featureId = switch (destinations[value].collection) {
      'workout_assignments' => 'training',
      'measurements' => 'progress',
      'billing' || 'payments' => 'billing',
      'class_sessions' => 'classes',
      'conversations' => 'chat',
      'configuration' => 'branding',
      final value => value,
    };
    unawaited(
      context
          .read<GymRepository>()
          .trackFeatureUsage(gymId: membership.gymId, featureId: featureId)
          .catchError((_) {}),
    );
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

class _MemberNotificationButton extends StatelessWidget {
  const _MemberNotificationButton({
    required this.membership,
    required this.onPressed,
  });

  final GymMembership membership;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: context.read<GymRepository>().notifications(
          membership.gymId,
          membership.uid,
        ),
        builder: (context, snapshot) {
          final unread =
              snapshot.data?.docs
                  .where((document) => document.data()['read'] != true)
                  .length ??
              0;
          return Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            offset: const Offset(-5, 5),
            child: IconButton(
              tooltip: unread == 0
                  ? 'Notifications'
                  : '$unread unread notifications',
              onPressed: onPressed,
              icon: Icon(
                unread == 0
                    ? Icons.notifications_outlined
                    : Icons.notifications,
              ),
            ),
          );
        },
      );
}

class _MemberNotificationDrawer extends StatelessWidget {
  const _MemberNotificationDrawer({required this.membership});
  final GymMembership membership;

  @override
  Widget build(BuildContext context) => Drawer(
    width: MediaQuery.sizeOf(context).width < 480
        ? MediaQuery.sizeOf(context).width * .92
        : 420,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.notifications_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(membership.gymName, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close notifications',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: context.read<GymRepository>().notifications(
                membership.gymId,
                membership.uid,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load notifications: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notifications = [...snapshot.data!.docs]
                  ..sort((a, b) {
                    final aTime =
                        (a.data()['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    final bTime =
                        (b.data()['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    return bTime.compareTo(aTime);
                  });
                if (notifications.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none, size: 48),
                          SizedBox(height: 12),
                          Text('You are all caught up'),
                          Text(
                            'Membership reminders and gym updates will appear here.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final unread = notifications
                    .where((document) => document.data()['read'] != true)
                    .toList();
                return Column(
                  children: [
                    if (unread.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => Future.wait(
                            unread.map(
                              (document) => context
                                  .read<GymRepository>()
                                  .markNotificationRead(
                                    gymId: membership.gymId,
                                    notificationId: document.id,
                                  ),
                            ),
                          ),
                          icon: const Icon(Icons.done_all),
                          label: const Text('Mark all read'),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        itemCount: notifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final document = notifications[index];
                          final data = document.data();
                          final isUnread = data['read'] != true;
                          final createdAt = (data['createdAt'] as Timestamp?)
                              ?.toDate();
                          return Card(
                            color: isUnread
                                ? Theme.of(context).colorScheme.primaryContainer
                                      .withValues(alpha: .35)
                                : null,
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Icon(
                                  data['type'] == 'subscription_expiry'
                                      ? Icons.schedule
                                      : Icons.notifications_outlined,
                                ),
                              ),
                              title: Text('${data['title'] ?? 'Notification'}'),
                              subtitle: Text(
                                [
                                  '${data['body'] ?? ''}',
                                  if (createdAt != null)
                                    DateFormat(
                                      'dd MMM, hh:mm a',
                                    ).format(createdAt),
                                ].where((value) => value.isNotEmpty).join('\n'),
                              ),
                              isThreeLine: createdAt != null,
                              trailing: isUnread
                                  ? const Icon(Icons.circle, size: 10)
                                  : const Icon(Icons.done, size: 18),
                              onTap: isUnread
                                  ? () => context
                                        .read<GymRepository>()
                                        .markNotificationRead(
                                          gymId: membership.gymId,
                                          notificationId: document.id,
                                        )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _WorkspaceContent extends StatelessWidget {
  const _WorkspaceContent({
    required this.destination,
    required this.membership,
    required this.onSwitchContext,
    required this.onExportData,
    required this.onDeleteAccount,
    required this.onSignOut,
  });
  final _Destination destination;
  final GymMembership membership;
  final Future<void> Function() onSwitchContext;
  final Future<void> Function() onExportData;
  final Future<void> Function() onDeleteAccount;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    if (destination.collection == 'dashboard') {
      if (membership.role == GymRole.member) {
        return MemberHomePanel(membership: membership);
      }
      return _Dashboard(membership: membership);
    }
    if (destination.collection == 'workout_assignments' &&
        membership.role == GymRole.member) {
      return MemberTrainingPanel(membership: membership);
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
    if (destination.collection == 'profile') {
      return MemberProfilePanel(
        membership: membership,
        onSwitchContext: onSwitchContext,
        onExportData: onExportData,
        onDeleteAccount: onDeleteAccount,
        onSignOut: onSignOut,
      );
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
        if (destination.collection == 'members')
          Expanded(
            child: _MemberDirectory(
              membership: membership,
              onEdit: (uid, data) => _editMembership(context, uid, data),
            ),
          )
        else
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream(context),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Unable to load: ${snapshot.error}'),
                  );
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
          title: Text(
            'Member · ${data['displayName'] ?? data['email'] ?? data['phone'] ?? 'profile incomplete'}',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data['email'] != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.email_outlined),
                  title: Text('${data['email']}'),
                ),
              if (data['phone'] != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_outlined),
                  title: Text('${data['phone']}'),
                ),
              if (data['onboardingCompletedAt'] == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'The member has not completed their fitness profile yet.',
                  ),
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
    final formKey = GlobalKey<FormState>();
    var role = destination.collection == 'members' ? 'member' : 'trainer';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            destination.collection == 'members'
                ? 'Invite a member'
                : 'Invite gym staff',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'We will create a secure, one-time link you can share using WhatsApp, Messages, Mail, or another app.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: email,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
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
                if (destination.collection == 'staff') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    items:
                        const [
                              'manager',
                              'receptionist',
                              'trainer',
                              'accountant',
                            ]
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Create invitation'),
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
        final invitation = GymInvitationLink(
          gymId: membership.gymId,
          token: response['token'] as String,
          gymName: membership.gymName,
          role: role,
          expiresInHours: response['expiresInHours'] as int? ?? 72,
        );
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _InvitationReadySheet(
            invitation: invitation,
            recipientEmail: email.text.trim(),
          ),
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

class _InvitationReadySheet extends StatelessWidget {
  const _InvitationReadySheet({
    required this.invitation,
    required this.recipientEmail,
  });

  final GymInvitationLink invitation;
  final String recipientEmail;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.outgoing_mail, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Invitation ready',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '$recipientEmail can join ${invitation.gymName} as a ${invitation.roleLabel}.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('Secure one-time invitation'),
                  subtitle: Text(
                    'Expires in ${invitation.expiresInHours} hours and only works with the invited email.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (buttonContext) => FilledButton.icon(
                  onPressed: () => _share(buttonContext),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share invitation'),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _copy(context),
                icon: const Icon(Icons.link),
                label: const Text('Copy invitation link'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
              const SizedBox(height: 4),
              const Text(
                'The person will appear in your member or staff list after accepting the invitation.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: invitation.shareMessage,
        subject: 'Invitation to join ${invitation.gymName}',
        title: 'Gym invitation',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: invitation.shareUri.toString()),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invitation link copied.')));
  }
}

class _MemberDirectory extends StatefulWidget {
  const _MemberDirectory({required this.membership, required this.onEdit});

  final GymMembership membership;
  final Future<void> Function(String uid, Map<String, dynamic> data) onEdit;

  @override
  State<_MemberDirectory> createState() => _MemberDirectoryState();
}

class _MemberDirectoryState extends State<_MemberDirectory> {
  final search = TextEditingController();
  bool identityRepairRequested = false;

  @override
  void initState() {
    super.initState();
    search.addListener(_refresh);
  }

  @override
  void dispose() {
    search
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: context.read<GymRepository>().recent(
      widget.membership.gymId,
      'members',
    ),
    builder: (context, memberSnapshot) {
      if (memberSnapshot.hasError) {
        return Center(
          child: Text('Unable to load members: ${memberSnapshot.error}'),
        );
      }
      if (!memberSnapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final allMembers = memberSnapshot.data!.docs;
      if (!identityRepairRequested &&
          allMembers.any((member) {
            final data = member.data();
            return data['displayName'] == null || data['email'] == null;
          })) {
        identityRepairRequested = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context
              .read<GymRepository>()
              .hydrateMemberProfiles(widget.membership.gymId)
              .catchError((_) => 0);
        });
      }
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: context.read<GymRepository>().subscriptions(
          widget.membership.gymId,
        ),
        builder: (context, subscriptionSnapshot) {
          final subscriptions = <String, Map<String, dynamic>>{
            for (final document
                in subscriptionSnapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
              (document.data()['memberUid'] as String? ?? document.id): document
                  .data(),
          };
          final query = search.text.trim().toLowerCase();
          final members = allMembers.where((member) {
            if (query.isEmpty) return true;
            final data = member.data();
            return [data['displayName'], data['email'], data['phone']]
                .whereType<Object>()
                .any((value) => value.toString().toLowerCase().contains(query));
          }).toList();
          final active = allMembers
              .where((member) => member.data()['status'] == 'active')
              .length;
          final incomplete = allMembers
              .where((member) => member.data()['onboardingCompletedAt'] == null)
              .length;
          return Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search name, email or phone',
                        isDense: true,
                      ),
                    ),
                  ),
                  Chip(label: Text('${allMembers.length} members')),
                  Chip(label: Text('$active active')),
                  if (incomplete > 0)
                    Chip(label: Text('$incomplete profiles incomplete')),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: members.isEmpty
                    ? Center(
                        child: Text(
                          allMembers.isEmpty
                              ? 'No members yet. Invite your first member.'
                              : 'No members match this search.',
                        ),
                      )
                    : ListView.separated(
                        itemCount: members.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final member = members[index];
                          return _MemberDirectoryCard(
                            uid: member.id,
                            data: member.data(),
                            subscription: subscriptions[member.id],
                            canEdit: widget.membership.can('members.write'),
                            onEdit: widget.onEdit,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _MemberDirectoryCard extends StatelessWidget {
  const _MemberDirectoryCard({
    required this.uid,
    required this.data,
    required this.subscription,
    required this.canEdit,
    required this.onEdit,
  });

  final String uid;
  final Map<String, dynamic> data;
  final Map<String, dynamic>? subscription;
  final bool canEdit;
  final Future<void> Function(String uid, Map<String, dynamic> data) onEdit;

  @override
  Widget build(BuildContext context) {
    final displayName = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim();
    final phone = (data['phone'] as String?)?.trim();
    final title = displayName?.isNotEmpty == true
        ? displayName!
        : email?.isNotEmpty == true
        ? email!
        : phone?.isNotEmpty == true
        ? phone!
        : 'Member profile incomplete';
    final endAt = (subscription?['endAt'] as Timestamp?)?.toDate();
    final planName = subscription?['planName'] ?? subscription?['planId'];
    final memberStatus = data['status'] as String? ?? 'active';
    final subscriptionStatus = subscription?['status'] as String?;
    final contact = [email, phone]
        .whereType<String>()
        .where((value) => value.isNotEmpty && value != title)
        .join('  •  ');
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canEdit ? () => onEdit(uid, data) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _MemberDirectoryAvatar(data: data),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (contact.isNotEmpty) Text(contact),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _DirectoryStatusChip(
                          label: memberStatus,
                          positive: memberStatus == 'active',
                        ),
                        if (planName != null)
                          Chip(
                            avatar: const Icon(Icons.card_membership, size: 16),
                            label: Text(
                              '$planName${endAt == null ? '' : ' · until ${DateFormat('dd MMM yyyy').format(endAt)}'}',
                            ),
                          )
                        else
                          const Chip(label: Text('No membership plan')),
                        if (subscriptionStatus != null &&
                            subscriptionStatus != 'active')
                          _DirectoryStatusChip(
                            label: subscriptionStatus,
                            positive: false,
                          ),
                        if (data['onboardingCompletedAt'] == null)
                          const Chip(label: Text('Profile incomplete')),
                      ],
                    ),
                  ],
                ),
              ),
              if (canEdit) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberDirectoryAvatar extends StatelessWidget {
  const _MemberDirectoryAvatar({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final path = data['photoPath'] as String?;
    final name = (data['displayName'] as String?)?.trim();
    final fallback = name?.isNotEmpty == true
        ? name!.substring(0, 1).toUpperCase()
        : null;
    if (path == null || path.isEmpty) {
      return CircleAvatar(
        radius: 26,
        child: fallback == null
            ? const Icon(Icons.person_outline)
            : Text(fallback),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: GymMediaRepository().readPrivatePhoto(path),
      builder: (context, snapshot) => CircleAvatar(
        radius: 26,
        backgroundImage: snapshot.data == null
            ? null
            : MemoryImage(snapshot.data!),
        child: snapshot.data == null
            ? (fallback == null
                  ? const Icon(Icons.person_outline)
                  : Text(fallback))
            : null,
      ),
    );
  }
}

class _DirectoryStatusChip extends StatelessWidget {
  const _DirectoryStatusChip({required this.label, required this.positive});
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      positive ? Icons.check_circle_outline : Icons.info_outline,
      size: 16,
    ),
    label: Text(label),
    backgroundColor: positive
        ? Colors.green.withValues(alpha: .12)
        : Theme.of(context).colorScheme.errorContainer.withValues(alpha: .55),
  );
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
  late final tagline = TextEditingController(text: widget.membership.tagline);
  late final currency = TextEditingController(text: widget.membership.currency);
  late final timezone = TextEditingController(text: widget.membership.timezone);
  late final locale = TextEditingController(text: widget.membership.locale);
  late final phone = TextEditingController(text: widget.membership.phone ?? '');
  late final city = TextEditingController(text: widget.membership.city ?? '');
  late final website = TextEditingController(
    text: widget.membership.website ?? '',
  );
  late final primaryColor = TextEditingController(
    text: widget.membership.primaryColor,
  );
  late final secondaryColor = TextEditingController(
    text: widget.membership.secondaryColor,
  );
  late final accentColor = TextEditingController(
    text: widget.membership.accentColor,
  );
  late String? logoUrl = widget.membership.logoUrl;
  bool saving = false;
  bool uploading = false;

  @override
  void dispose() {
    name.dispose();
    tagline.dispose();
    currency.dispose();
    timezone.dispose();
    locale.dispose();
    primaryColor.dispose();
    secondaryColor.dispose();
    accentColor.dispose();
    phone.dispose();
    city.dispose();
    website.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('Gym settings', style: Theme.of(context).textTheme.headlineMedium),
      const Text(
        'Your logo, name and colors update for members at runtime across the shared app.',
      ),
      const SizedBox(height: 20),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _hexColor(primaryColor.text, const Color(0xFF2563EB)),
                _hexColor(accentColor.text, const Color(0xFFF97316)),
              ],
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox.square(
                  dimension: 72,
                  child: logoUrl == null
                      ? const ColoredBox(
                          color: Colors.white,
                          child: Icon(Icons.fitness_center, size: 36),
                        )
                      : Image.network(
                          logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Colors.white,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.text,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      tagline.text,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      OutlinedButton.icon(
        onPressed: uploading ? null : _uploadLogo,
        icon: const Icon(Icons.upload_outlined),
        label: Text(uploading ? 'Uploading logo…' : 'Choose gym logo'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: name,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Gym name'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: tagline,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Member tagline'),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _GymColorField(
            label: 'Primary',
            controller: primaryColor,
            onChanged: (_) => setState(() {}),
          ),
          _GymColorField(
            label: 'Secondary',
            controller: secondaryColor,
            onChanged: (_) => setState(() {}),
          ),
          _GymColorField(
            label: 'Accent',
            controller: accentColor,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      const Divider(height: 32),
      Text('Business profile', style: Theme.of(context).textTheme.titleMedium),
      TextField(
        controller: phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Phone'),
      ),
      TextField(
        controller: city,
        decoration: const InputDecoration(labelText: 'City'),
      ),
      TextField(
        controller: website,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(labelText: 'Website (https://…)'),
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
      const Text('App features are controlled by your active platform plan.'),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: saving || uploading ? null : _save,
        child: Text(saving ? 'Saving…' : 'Save settings'),
      ),
    ],
  );

  Future<void> _uploadLogo() async {
    setState(() => uploading = true);
    try {
      final uploaded = await context
          .read<GymMediaRepository>()
          .pickAndUploadGymLogo(gymId: widget.membership.gymId);
      if (mounted && uploaded != null) setState(() => logoUrl = uploaded);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

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
        secondaryColor: secondaryColor.text.trim(),
        accentColor: accentColor.text.trim(),
        tagline: tagline.text.trim(),
        logoUrl: logoUrl,
        phone: phone.text,
        city: city.text,
        website: website.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Branding saved and updated for active members.'),
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

class _GymColorField extends StatelessWidget {
  const _GymColorField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: '$label #RRGGBB',
        prefixIcon: Padding(
          padding: const EdgeInsets.all(13),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hexColor(controller.text, Colors.grey),
            ),
          ),
        ),
      ),
    ),
  );
}

Color _hexColor(String value, Color fallback) {
  final hex = value.replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) return fallback;
  return Color(int.parse('FF$hex', radix: 16));
}

class _Destination {
  const _Destination(this.label, this.icon, this.collection);
  final String label;
  final IconData icon;
  final String collection;
}
