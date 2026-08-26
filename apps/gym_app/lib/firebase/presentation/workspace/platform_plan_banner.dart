import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_core/gym_core.dart';

import '../../data/gym_repository.dart';

class PlatformPlanBanner extends StatelessWidget {
  const PlatformPlanBanner({required this.membership, super.key});
  final GymMembership membership;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: context.read<GymRepository>().platformSubscription(
      membership.gymId,
    ),
    builder: (context, subscriptionSnapshot) =>
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: context.read<GymRepository>().usage(membership.gymId),
          builder: (context, usageSnapshot) {
            final subscription =
                subscriptionSnapshot.data?.data() ?? const <String, dynamic>{};
            final usage =
                usageSnapshot.data?.data() ?? const <String, dynamic>{};
            final limits = Map<String, dynamic>.from(
              subscription['limits'] as Map? ?? const {},
            );
            final end = subscription['endsAt'] as Timestamp?;
            final days = end == null
                ? null
                : end.toDate().difference(DateTime.now()).inDays + 1;
            final trial = subscription['status'] == 'trial';
            return Card(
              color: trial
                  ? Theme.of(context).colorScheme.tertiaryContainer
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(trial ? Icons.hourglass_top : Icons.verified_outlined),
                    SizedBox(
                      width: 190,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subscription['planName'] as String? ??
                                'Platform plan',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            trial
                                ? '${days ?? '—'} days left in trial'
                                : 'Plan active',
                          ),
                        ],
                      ),
                    ),
                    _Usage(
                      label: 'Members',
                      used: usage['activeMembers'],
                      limit: limits['activeMembers'],
                    ),
                    _Usage(
                      label: 'Trainers',
                      used: usage['activeTrainers'],
                      limit: limits['activeTrainers'],
                    ),
                    _Usage(
                      label: 'Staff',
                      used: usage['activeStaff'],
                      limit: limits['activeStaff'],
                    ),
                    _Usage(
                      label: 'Classes',
                      used: usage['scheduledClasses'],
                      limit: limits['scheduledClasses'],
                    ),
                    if (membership.role == GymRole.owner)
                      FilledButton.tonal(
                        onPressed: () => _showUpgrade(context),
                        child: const Text('Upgrade'),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
  );

  Future<void> _showUpgrade(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _UpgradeDialog(membership: membership),
    );
  }
}

class _Usage extends StatelessWidget {
  const _Usage({required this.label, this.used, this.limit});
  final String label;
  final Object? used;
  final Object? limit;

  @override
  Widget build(BuildContext context) =>
      Chip(label: Text('$label ${used ?? 0}/${limit ?? '—'}'));
}

class _UpgradeDialog extends StatefulWidget {
  const _UpgradeDialog({required this.membership});
  final GymMembership membership;

  @override
  State<_UpgradeDialog> createState() => _UpgradeDialogState();
}

class _UpgradeDialogState extends State<_UpgradeDialog> {
  String? selected;
  final note = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Request an upgrade'),
    content: SizedBox(
      width: 480,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: context.read<GymRepository>().publicSaasPlans(),
        builder: (context, snapshot) {
          final plans =
              snapshot.data?.docs
                  .where((doc) => doc.data()['isTrial'] != true)
                  .toList() ??
              [];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Choose plan'),
                items: plans.map((doc) {
                  final data = doc.data();
                  final price = (data['priceMinor'] as num? ?? 0) / 100;
                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text(
                      '${data['name'] ?? doc.id} · ₹${price.toStringAsFixed(0)} / ${data['billingPeriod'] ?? 'month'}',
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selected = value),
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 8),
              const Text(
                'No payment is taken now. The platform administrator reviews and activates the plan.',
              ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving || selected == null ? null : _submit,
        child: Text(saving ? 'Sending…' : 'Send request'),
      ),
    ],
  );

  Future<void> _submit() async {
    setState(() => saving = true);
    try {
      await context.read<GymRepository>().requestPlatformUpgrade(
        gymId: widget.membership.gymId,
        planId: selected!,
        note: note.text,
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Request failed')),
        );
      }
      if (mounted) setState(() => saving = false);
    }
  }
}
