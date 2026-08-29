import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_core/gym_core.dart';

import '../../data/gym_repository.dart';
import '../../data/support_repository.dart';
import 'support_hub_screen.dart';

class GymSupportPanel extends StatelessWidget {
  const GymSupportPanel({
    required this.membership,
    required this.onBack,
    super.key,
  });
  final GymMembership membership;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back to dashboard',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support inbox',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    'Coaching and gym questions are routed by your permissions.',
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _startForMember(context),
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('New case'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: context.read<SupportRepository>().gymThreads(membership),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 42),
                        const SizedBox(height: 12),
                        Text(
                          'Support requests could not be loaded.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Check your connection, then reopen Support. No request data was changed.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No support requests yet.'));
              }
              return ListView.separated(
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final document = snapshot.data!.docs[index];
                  final data = document.data();
                  final identity = Map<String, dynamic>.from(
                    data['memberIdentity'] as Map? ?? const {},
                  );
                  final memberName =
                      identity['displayName'] ?? identity['email'] ?? 'Member';
                  final assigned = data['assignedUid'] as String?;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          data['category'] == 'coaching'
                              ? Icons.sports_gymnastics_outlined
                              : Icons.support_agent_outlined,
                        ),
                      ),
                      title: Text(
                        data['subject'] as String? ?? 'Support request',
                      ),
                      subtitle: Text(
                        '$memberName · ${_categoryLabel(data['category'])}\n${_statusLabel(data['status'])} · ${data['lastMessage'] ?? ''}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Support actions',
                        onSelected: (value) {
                          if (value == 'claim') {
                            _claim(context, document.id);
                          } else if (value == 'assign') {
                            _assign(context, document.id, data);
                          }
                        },
                        itemBuilder: (_) => [
                          if (assigned == null)
                            const PopupMenuItem(
                              value: 'claim',
                              child: Text('Claim request'),
                            ),
                          if (membership.can('staff.manage') ||
                              membership.can('support.manage'))
                            const PopupMenuItem(
                              value: 'assign',
                              child: Text('Assign teammate'),
                            ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SupportConversationScreen(
                            scopeType: 'gym',
                            ownerUid: membership.uid,
                            gymId: membership.gymId,
                            targetUid: data['memberUid'] as String?,
                            threadId: document.id,
                            subject:
                                data['subject'] as String? ?? 'Support request',
                            staffMode: true,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );

  Future<void> _claim(BuildContext context, String threadId) async {
    try {
      await context.read<SupportRepository>().claim(
        gymId: membership.gymId,
        threadId: threadId,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to claim request: $error')),
        );
      }
    }
  }

  Future<void> _assign(
    BuildContext context,
    String threadId,
    Map<String, dynamic> thread,
  ) async {
    final firestore = context.read<GymRepository>().firestore;
    final results = await Future.wait([
      firestore
          .collection('gym_memberships')
          .where('gymId', isEqualTo: membership.gymId)
          .limit(100)
          .get(),
      firestore.collection('gyms/${membership.gymId}/staff').limit(100).get(),
    ]);
    final snapshot = results[0];
    final staff = results[1];
    final identities = {
      for (final profile in staff.docs) profile.id: profile.data(),
    };
    final category = thread['category'] as String? ?? 'other';
    final requiredPermission = category == 'coaching'
        ? 'support.coaching'
        : category == 'payment'
        ? 'support.billing'
        : 'support.manage';
    final teammates = snapshot.docs.where((document) {
      final data = document.data();
      final permissions = Map<String, bool>.from(
        data['permissions'] as Map? ?? const {},
      );
      final candidate = GymMembership(
        id: document.id,
        gymId: membership.gymId,
        uid: data['uid'] as String? ?? document.id,
        role: GymRole.fromJson(data['role'] as String? ?? 'member'),
        status: data['status'] as String? ?? 'inactive',
        permissions: permissions,
      );
      return candidate.status == 'active' && candidate.can(requiredPermission);
    }).toList();
    if (!context.mounted) return;
    if (teammates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible teammate is available.')),
      );
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Assign teammate'),
        children: teammates
            .map(
              (teammate) => SimpleDialogOption(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  teammate.data()['uid'] as String? ?? teammate.id,
                ),
                child: Text(
                  identities[teammate.data()['uid']]?['displayName']
                          as String? ??
                      identities[teammate.data()['uid']]?['email'] as String? ??
                      '${teammate.data()['role'] ?? 'Staff'} teammate',
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || !context.mounted) return;
    try {
      await context.read<SupportRepository>().assignThread(
        gymId: membership.gymId,
        threadId: threadId,
        assigneeUid: selected,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to assign request: $error')),
        );
      }
    }
  }

  Future<void> _startForMember(BuildContext context) async {
    final members = await context
        .read<GymRepository>()
        .firestore
        .collection('gyms/${membership.gymId}/members')
        .where('status', isEqualTo: 'active')
        .limit(100)
        .get();
    if (!context.mounted) return;
    if (members.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active members are available.')),
      );
      return;
    }
    final result = await showDialog<_StaffCase>(
      context: context,
      builder: (_) =>
          _StaffCaseDialog(membership: membership, members: members.docs),
    );
    if (result == null || !context.mounted) return;
    try {
      await context.read<SupportRepository>().createGymThread(
        gymId: membership.gymId,
        category: result.category,
        memberUid: result.memberUid,
        reason: result.reason,
        subject: result.subject,
        message: result.message,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to create support case: $error')),
        );
      }
    }
  }
}

class _StaffCase {
  const _StaffCase({
    required this.memberUid,
    required this.category,
    required this.reason,
    required this.subject,
    required this.message,
  });
  final String memberUid;
  final String category;
  final String reason;
  final String subject;
  final String message;
}

class _StaffCaseDialog extends StatefulWidget {
  const _StaffCaseDialog({required this.membership, required this.members});
  final GymMembership membership;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> members;

  @override
  State<_StaffCaseDialog> createState() => _StaffCaseDialogState();
}

class _StaffCaseDialogState extends State<_StaffCaseDialog> {
  final formKey = GlobalKey<FormState>();
  final reason = TextEditingController();
  final subject = TextEditingController();
  final message = TextEditingController();
  late String memberUid = widget.members.first.id;
  late final categories = <String, String>{
    if (widget.membership.can('support.coaching'))
      'coaching': 'Exercise or routine guidance',
    if (widget.membership.can('support.billing')) 'payment': 'Payment',
    if (widget.membership.can('support.manage')) ...{
      'membership': 'Membership',
      'attendance': 'Attendance',
      'classes': 'Classes',
      'facility': 'Gym facility',
      'other': 'Something else',
    },
  };
  late String category = categories.keys.first;

  @override
  void dispose() {
    reason.dispose();
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Start member support case'),
    content: Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: memberUid,
              decoration: const InputDecoration(labelText: 'Member'),
              items: widget.members
                  .map(
                    (document) => DropdownMenuItem(
                      value: document.id,
                      child: Text(
                        document.data()['displayName'] as String? ??
                            document.data()['email'] as String? ??
                            'Member',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => memberUid = value ?? memberUid,
            ),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Topic'),
              items: categories.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) => category = value ?? category,
            ),
            TextFormField(
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Internal reason for contacting this member',
              ),
              maxLength: 500,
              validator: (value) => (value?.trim().length ?? 0) < 12
                  ? 'Enter at least 12 characters.'
                  : null,
            ),
            TextFormField(
              controller: subject,
              decoration: const InputDecoration(labelText: 'Subject'),
              maxLength: 120,
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Enter at least 3 characters.'
                  : null,
            ),
            TextFormField(
              controller: message,
              decoration: const InputDecoration(labelText: 'Message'),
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Enter a message.' : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _StaffCase(
              memberUid: memberUid,
              category: category,
              reason: reason.text.trim(),
              subject: subject.text.trim(),
              message: message.text.trim(),
            ),
          );
        },
        child: const Text('Open case'),
      ),
    ],
  );
}

String _categoryLabel(dynamic value) => switch (value) {
  'coaching' => 'Coaching',
  'payment' => 'Payment',
  'attendance' => 'Attendance',
  'classes' => 'Classes',
  'facility' => 'Facility',
  'membership' => 'Membership',
  _ => 'Gym support',
};

String _statusLabel(dynamic value) => switch (value) {
  'waitingOnSupport' => 'Waiting for team',
  'waitingOnUser' => 'Waiting for member',
  'resolved' => 'Resolved',
  'closed' => 'Closed',
  _ => 'Open',
};
