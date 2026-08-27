import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/gym_repository.dart';
import 'package:gym_core/gym_core.dart';

class MemberSubscriptionBanner extends StatefulWidget {
  const MemberSubscriptionBanner({required this.membership, super.key});

  final GymMembership membership;

  @override
  State<MemberSubscriptionBanner> createState() =>
      _MemberSubscriptionBannerState();
}

class _MemberSubscriptionBannerState extends State<MemberSubscriptionBanner> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> subscriptionStream;

  GymMembership get membership => widget.membership;

  @override
  void initState() {
    super.initState();
    subscriptionStream = _stream();
  }

  @override
  void didUpdateWidget(covariant MemberSubscriptionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.membership.gymId != membership.gymId ||
        oldWidget.membership.uid != membership.uid) {
      subscriptionStream = _stream();
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _stream() => context
      .read<GymRepository>()
      .memberSubscription(membership.gymId, membership.uid);

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: subscriptionStream,
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      if (!snapshot.data!.exists) {
        return const Card(
          child: ListTile(
            leading: Icon(Icons.warning_amber_rounded),
            title: Text('No active membership plan'),
            subtitle: Text('Open Membership to request a plan.'),
          ),
        );
      }
      final data = snapshot.data!.data()!;
      final endAt = (data['endAt'] as Timestamp?)?.toDate();
      final health = subscriptionHealth(
        storedStatus: data['status'] as String? ?? 'active',
        endsAt: endAt,
        now: DateTime.now(),
      );
      if (health == SubscriptionHealth.active) return const SizedBox.shrink();
      final (title, color, icon) = switch (health) {
        SubscriptionHealth.expiringSoon => (
          'Membership expiring soon',
          Colors.orange,
          Icons.schedule,
        ),
        SubscriptionHealth.expired => (
          'Membership expired',
          Colors.red,
          Icons.event_busy_outlined,
        ),
        SubscriptionHealth.paused => (
          'Membership paused',
          Colors.blueGrey,
          Icons.pause_circle_outline,
        ),
        SubscriptionHealth.cancelled => (
          'Membership cancelled',
          Colors.grey,
          Icons.cancel_outlined,
        ),
        SubscriptionHealth.active => (
          'Membership active',
          Colors.green,
          Icons.verified_outlined,
        ),
      };
      return Card(
        color: color.withValues(alpha: .1),
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(title),
          subtitle: Text(
            endAt == null
                ? 'Select a membership plan to continue.'
                : '${data['planName'] ?? data['planId']} · ${health == SubscriptionHealth.expired ? 'Ended' : 'Ends'} ${DateFormat('dd MMM yyyy').format(endAt)}',
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
    },
  );
}

class MemberBillingPanel extends StatelessWidget {
  const MemberBillingPanel({required this.membership, super.key});

  final GymMembership membership;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My membership',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text(
                'Plan, renewal, receipts, and reminders in one place.',
              ),
            ],
          ),
        ),
        const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Membership'),
            Tab(text: 'Payments'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _MembershipTab(membership: membership),
              _MemberPaymentsTab(membership: membership),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MembershipTab extends StatelessWidget {
  const _MembershipTab({required this.membership});
  final GymMembership membership;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      _CurrentMembershipCard(membership: membership),
      const SizedBox(height: 20),
      Text('Renewal plans', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      const Text(
        'Choose a plan to send a renewal request. The gym will confirm payment instructions.',
      ),
      const SizedBox(height: 12),
      _RenewalPlans(membership: membership),
      const SizedBox(height: 20),
      Card(
        child: ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Online checkout is not connected yet'),
          subtitle: const Text(
            'A payment provider account and verified webhook are required before UPI/card payments can safely go live.',
          ),
          trailing: OutlinedButton(
            onPressed: null,
            child: const Text('Pay online'),
          ),
        ),
      ),
    ],
  );
}

class _CurrentMembershipCard extends StatelessWidget {
  const _CurrentMembershipCard({required this.membership});
  final GymMembership membership;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: context.read<GymRepository>().memberSubscription(
          membership.gymId,
          membership.uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _ErrorText(snapshot.error);
          if (!snapshot.hasData) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: LinearProgressIndicator(),
              ),
            );
          }
          if (!snapshot.data!.exists) {
            return const Card(
              child: ListTile(
                leading: Icon(Icons.card_membership),
                title: Text('No membership assigned'),
                subtitle: Text('Choose a plan below to request membership.'),
              ),
            );
          }
          final data = snapshot.data!.data()!;
          final startAt = (data['startAt'] as Timestamp?)?.toDate();
          final endAt = (data['endAt'] as Timestamp?)?.toDate();
          final health = subscriptionHealth(
            storedStatus: data['status'] as String? ?? 'active',
            endsAt: endAt,
            now: DateTime.now(),
          );
          final days = endAt?.difference(DateTime.now()).inDays;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(child: Icon(Icons.card_membership)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${data['planName'] ?? data['planId']}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(membership.gymName),
                          ],
                        ),
                      ),
                      _HealthChip(health: health),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 28,
                    runSpacing: 12,
                    children: [
                      _DateValue(label: 'Started', date: startAt),
                      _DateValue(label: 'Valid until', date: endAt),
                      _TextValue(
                        label: 'Remaining',
                        value: days == null
                            ? '—'
                            : days < 0
                            ? 'Expired'
                            : '$days days',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _RenewalPlans extends StatelessWidget {
  const _RenewalPlans({required this.membership});
  final GymMembership membership;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: context.read<GymRepository>().renewalRequest(
      membership.gymId,
      membership.uid,
    ),
    builder: (context, requestSnapshot) =>
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: context.read<GymRepository>().membershipPlans(
            membership.gymId,
          ),
          builder: (context, plansSnapshot) {
            if (plansSnapshot.hasError) return _ErrorText(plansSnapshot.error);
            if (!plansSnapshot.hasData) return const LinearProgressIndicator();
            final pending = requestSnapshot.data?.data();
            final hasPending = pending?['status'] == 'pending';
            final plans = plansSnapshot.data!.docs
                .where((plan) => plan.data()['status'] == 'active')
                .toList();
            if (plans.isEmpty) {
              return const Text('No renewal plans are available.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPending)
                  Card(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: .45),
                    child: ListTile(
                      leading: const Icon(Icons.pending_actions),
                      title: const Text('Renewal request pending'),
                      subtitle: Text(
                        '${pending?['planName']} · waiting for gym confirmation',
                      ),
                    ),
                  ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    mainAxisExtent: 190,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    final data = plan.data();
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${data['name']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              _money(
                                (data['priceMinor'] as num?)?.toInt() ?? 0,
                                data['currency'] as String? ?? 'INR',
                              ),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text('${data['durationDays']} days'),
                            const Spacer(),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: hasPending
                                    ? null
                                    : () => _request(context, plan.id),
                                child: Text(
                                  hasPending
                                      ? 'Request pending'
                                      : 'Request renewal',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
  );

  Future<void> _request(BuildContext context, String planId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request this renewal?'),
        content: const Text(
          'This sends a request to your gym. It does not charge you yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<GymRepository>().requestMembershipRenewal(
        gymId: membership.gymId,
        planId: planId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Renewal request sent to the gym.')),
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

class _MemberPaymentsTab extends StatelessWidget {
  const _MemberPaymentsTab({required this.membership});
  final GymMembership membership;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: context.read<GymRepository>().memberPayments(
      membership.gymId,
      membership.uid,
    ),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: _ErrorText(snapshot.error));
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.data!.docs.isEmpty) {
        return const _EmptyMemberState(
          icon: Icons.receipt_long_outlined,
          message: 'No payment receipts yet',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: snapshot.data!.docs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final document = snapshot.data!.docs[index];
          final data = document.data();
          final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.receipt_outlined)),
              title: Text('${data['planName'] ?? data['planId']}'),
              subtitle: Text(
                '${data['receiptNumber'] ?? document.id} · ${_method(data['method'])}\n${paidAt == null ? '' : DateFormat('dd MMM yyyy, hh:mm a').format(paidAt)}',
              ),
              isThreeLine: true,
              trailing: Text(
                _money(
                  (data['amountMinor'] as num?)?.toInt() ?? 0,
                  data['currency'] as String? ?? 'INR',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () => _showReceipt(context, data, document.id),
            ),
          );
        },
      );
    },
  );

  Future<void> _showReceipt(
    BuildContext context,
    Map<String, dynamic> data,
    String documentId,
  ) async {
    final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
    final receipt = data['receiptNumber'] as String? ?? documentId;
    final summary = [
      membership.gymName,
      'Receipt: $receipt',
      'Plan: ${data['planName'] ?? data['planId']}',
      'Amount: ${_money((data['amountMinor'] as num?)?.toInt() ?? 0, data['currency'] as String? ?? 'INR')}',
      'Method: ${_method(data['method'])}',
      if (paidAt != null)
        'Paid: ${DateFormat('dd MMM yyyy, hh:mm a').format(paidAt)}',
      if ('${data['reference'] ?? ''}'.isNotEmpty)
        'Reference: ${data['reference']}',
    ].join('\n');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(receipt),
        content: SelectableText(summary),
        actions: [
          TextButton(
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: summary, subject: '$receipt payment receipt'),
            ),
            child: const Text('Share'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.health});
  final SubscriptionHealth health;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (health) {
      SubscriptionHealth.active => ('Active', Colors.green),
      SubscriptionHealth.expiringSoon => ('Expiring', Colors.orange),
      SubscriptionHealth.expired => ('Expired', Colors.red),
      SubscriptionHealth.paused => ('Paused', Colors.blueGrey),
      SubscriptionHealth.cancelled => ('Cancelled', Colors.grey),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: .1),
      side: BorderSide(color: color.withValues(alpha: .5)),
    );
  }
}

class _DateValue extends StatelessWidget {
  const _DateValue({required this.label, required this.date});
  final String label;
  final DateTime? date;

  @override
  Widget build(BuildContext context) => _TextValue(
    label: label,
    value: date == null ? '—' : DateFormat('dd MMM yyyy').format(date!),
  );
}

class _TextValue extends StatelessWidget {
  const _TextValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _EmptyMemberState extends StatelessWidget {
  const _EmptyMemberState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(message),
      ],
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error);
  final Object? error;

  @override
  Widget build(BuildContext context) => Text('Unable to load: $error');
}

String _money(int minor, String currency) => NumberFormat.simpleCurrency(
  name: currency,
  decimalDigits: minor % 100 == 0 ? 0 : 2,
).format(minor / 100);

String _method(Object? value) => switch (value) {
  'upi' => 'UPI',
  'cash' => 'Cash',
  'card' => 'Card',
  'bank_transfer' => 'Bank transfer',
  _ => 'Other',
};
