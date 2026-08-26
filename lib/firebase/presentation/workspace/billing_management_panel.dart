import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/gym_repository.dart';
import '../../domain/billing_domain.dart';
import '../../domain/gym_context.dart';

class BillingManagementPanel extends StatelessWidget {
  const BillingManagementPanel({required this.membership, super.key});

  final GymMembership membership;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payments & subscriptions',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Text(
                  'Manage plans, renewals, expiry, and immutable payment records.',
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (membership.can('payments.read'))
                  OutlinedButton.icon(
                    onPressed: () => _exportPayments(context),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export'),
                  ),
                if (membership.can('payments.write'))
                  FilledButton.icon(
                    onPressed: () => _recordRenewal(context),
                    icon: const Icon(Icons.add_card),
                    label: const Text('Record renewal'),
                  ),
              ],
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: constraints.maxWidth < 700
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, const SizedBox(height: 12), actions],
                    )
                  : Row(
                      children: [
                        Expanded(child: title),
                        actions,
                      ],
                    ),
            );
          },
        ),
        const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Subscriptions'),
            Tab(text: 'Payments'),
            Tab(text: 'Plans'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _BillingOverview(membership: membership),
              _SubscriptionsList(membership: membership),
              _PaymentsList(membership: membership),
              _PlansList(membership: membership),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _recordRenewal(BuildContext context) async {
    final repository = context.read<GymRepository>();
    try {
      final results = await Future.wait([
        repository.activeMembers(membership.gymId),
        repository.activePlans(membership.gymId),
      ]);
      if (!context.mounted) return;
      final members = results[0];
      final plans = results[1];
      if (members.isEmpty || plans.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              members.isEmpty
                  ? 'Add an active member before recording a renewal.'
                  : 'Create an active membership plan first.',
            ),
          ),
        );
        return;
      }
      final input = await showDialog<_RenewalInput>(
        context: context,
        builder: (_) => _RenewalDialog(members: members, plans: plans),
      );
      if (input == null || !context.mounted) return;
      final result = await repository.recordPayment(
        gymId: membership.gymId,
        memberUid: input.memberUid,
        planId: input.planId,
        amountMinor: input.amountMinor,
        method: input.method,
        startsAt: input.requestedStart,
        reference: input.reference,
        notes: input.notes,
      );
      if (!context.mounted) return;
      final endsAt = DateTime.fromMillisecondsSinceEpoch(
        result['endsAtMillis'] as int,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['receiptNumber']} recorded · valid through ${DateFormat('dd MMM yyyy').format(endsAt)}',
          ),
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

  Future<void> _exportPayments(BuildContext context) async {
    try {
      final repository = context.read<GymRepository>();
      final reports = await Future.wait([
        repository.exportCsv(gymId: membership.gymId, collection: 'payments'),
        repository.exportCsv(
          gymId: membership.gymId,
          collection: 'subscriptions',
        ),
      ]);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(reports[0])),
              mimeType: 'text/csv',
              name: '${membership.gymId}-payments.csv',
            ),
            XFile.fromData(
              Uint8List.fromList(utf8.encode(reports[1])),
              mimeType: 'text/csv',
              name: '${membership.gymId}-subscriptions.csv',
            ),
          ],
          subject: '${membership.gymName} payment reports',
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
}

class _BillingOverview extends StatelessWidget {
  const _BillingOverview({required this.membership});

  final GymMembership membership;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: context.read<GymRepository>().subscriptions(membership.gymId),
    builder: (context, subscriptionsSnapshot) =>
        StreamBuilder<Map<String, dynamic>>(
          stream: context.read<GymRepository>().dashboard(membership.gymId),
          builder: (context, metricsSnapshot) {
            if (subscriptionsSnapshot.hasError) {
              return _ErrorState(error: subscriptionsSnapshot.error);
            }
            if (!subscriptionsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final now = DateTime.now();
            var active = 0;
            var expiring = 0;
            var expired = 0;
            for (final document in subscriptionsSnapshot.data!.docs) {
              final data = document.data();
              final health = subscriptionHealth(
                storedStatus: data['status'] as String? ?? 'active',
                endsAt: (data['endAt'] as Timestamp?)?.toDate(),
                now: now,
              );
              switch (health) {
                case SubscriptionHealth.active:
                  active++;
                case SubscriptionHealth.expiringSoon:
                  expiring++;
                case SubscriptionHealth.expired:
                  expired++;
                case SubscriptionHealth.paused:
                case SubscriptionHealth.cancelled:
                  break;
              }
            }
            final metrics = metricsSnapshot.data ?? const {};
            final revenue =
                (metrics['monthlyRevenueMinor'] as num?)?.toInt() ?? 0;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1000
                        ? 4
                        : constraints.maxWidth >= 560
                        ? 2
                        : 1;
                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: columns == 1 ? 3.2 : 2.1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        _MetricCard(
                          label: 'Active subscriptions',
                          value: '$active',
                          icon: Icons.verified_outlined,
                        ),
                        _MetricCard(
                          label: 'Expiring in 7 days',
                          value: '$expiring',
                          icon: Icons.schedule,
                          color: Colors.orange,
                        ),
                        _MetricCard(
                          label: 'Expired',
                          value: '$expired',
                          icon: Icons.event_busy_outlined,
                          color: Colors.red,
                        ),
                        _MetricCard(
                          label: 'Revenue this month',
                          value: _money(revenue, 'INR'),
                          icon: Icons.currency_rupee,
                          color: Colors.green,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Renewals extend existing active periods'),
                    subtitle: Text(
                      'If a member renews early, the new plan starts after the current expiry. Payment records remain immutable.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _RenewalRequestsCard(membership: membership),
              ],
            );
          },
        ),
  );
}

class _RenewalRequestsCard extends StatelessWidget {
  const _RenewalRequestsCard({required this.membership});
  final GymMembership membership;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: context.read<GymRepository>().renewalRequests(membership.gymId),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final pending = snapshot.data!.docs
          .where((document) => document.data()['status'] == 'pending')
          .toList();
      if (pending.isEmpty) return const SizedBox.shrink();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending renewal requests (${pending.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...pending.take(5).map((document) {
                final data = document.data();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.pending_actions),
                  ),
                  title: Text('${data['memberName'] ?? data['memberUid']}'),
                  subtitle: Text('${data['planName'] ?? data['planId']}'),
                  trailing: Text(
                    _money(
                      (data['amountMinor'] as num?)?.toInt() ?? 0,
                      data['currency'] as String? ?? 'INR',
                    ),
                  ),
                );
              }),
              const Text(
                'Use Record renewal after receiving payment. The request will be completed automatically.',
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SubscriptionsList extends StatefulWidget {
  const _SubscriptionsList({required this.membership});
  final GymMembership membership;

  @override
  State<_SubscriptionsList> createState() => _SubscriptionsListState();
}

class _SubscriptionsListState extends State<_SubscriptionsList> {
  String query = '';
  String filter = 'all';

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ListFilters(
        hint: 'Search member or plan',
        value: filter,
        options: const {
          'all': 'All statuses',
          'active': 'Active',
          'expiringSoon': 'Expiring soon',
          'expired': 'Expired',
        },
        onSearch: (value) => setState(() => query = value.toLowerCase()),
        onFilter: (value) => setState(() => filter = value),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: context.read<GymRepository>().subscriptions(
            widget.membership.gymId,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _ErrorState(error: snapshot.error);
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final now = DateTime.now();
            final rows = snapshot.data!.docs.where((document) {
              final data = document.data();
              final name = '${data['memberName'] ?? document.id}'.toLowerCase();
              final plan = '${data['planName'] ?? data['planId'] ?? ''}'
                  .toLowerCase();
              final health = subscriptionHealth(
                storedStatus: data['status'] as String? ?? 'active',
                endsAt: (data['endAt'] as Timestamp?)?.toDate(),
                now: now,
              );
              return (query.isEmpty ||
                      name.contains(query) ||
                      plan.contains(query)) &&
                  (filter == 'all' || health.name == filter);
            }).toList();
            if (rows.isEmpty) {
              return const _EmptyState(
                icon: Icons.card_membership,
                message: 'No matching subscriptions',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final data = rows[index].data();
                final endAt = (data['endAt'] as Timestamp?)?.toDate();
                final health = subscriptionHealth(
                  storedStatus: data['status'] as String? ?? 'active',
                  endsAt: endAt,
                  now: now,
                );
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(_initial(data['memberName'])),
                    ),
                    title: Text('${data['memberName'] ?? rows[index].id}'),
                    subtitle: Text(
                      '${data['planName'] ?? data['planId'] ?? 'Plan'} · ${endAt == null ? 'No expiry' : 'Ends ${DateFormat('dd MMM yyyy').format(endAt)}'}',
                    ),
                    trailing: _StatusChip(health: health),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

class _PaymentsList extends StatefulWidget {
  const _PaymentsList({required this.membership});
  final GymMembership membership;

  @override
  State<_PaymentsList> createState() => _PaymentsListState();
}

class _PaymentsListState extends State<_PaymentsList> {
  String query = '';
  String method = 'all';

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ListFilters(
        hint: 'Search member, receipt, or reference',
        value: method,
        options: const {
          'all': 'All methods',
          'upi': 'UPI',
          'cash': 'Cash',
          'card': 'Card',
          'bank_transfer': 'Bank transfer',
          'other': 'Other',
        },
        onSearch: (value) => setState(() => query = value.toLowerCase()),
        onFilter: (value) => setState(() => method = value),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: context.read<GymRepository>().payments(
            widget.membership.gymId,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _ErrorState(error: snapshot.error);
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data!.docs.where((document) {
              final data = document.data();
              final haystack = [
                data['memberName'],
                data['receiptNumber'],
                data['reference'],
                data['planName'],
              ].join(' ').toLowerCase();
              return (query.isEmpty || haystack.contains(query)) &&
                  (method == 'all' || data['method'] == method);
            }).toList();
            if (rows.isEmpty) {
              return const _EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'No matching payments',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final data = rows[index].data();
                final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long_outlined),
                    ),
                    title: Text('${data['memberName'] ?? data['memberUid']}'),
                    subtitle: Text(
                      '${data['receiptNumber'] ?? rows[index].id} · ${data['planName'] ?? data['planId']}\n${paidAt == null ? '' : DateFormat('dd MMM yyyy, hh:mm a').format(paidAt)} · ${_methodLabel(data['method'])}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      _money(
                        (data['amountMinor'] as num?)?.toInt() ?? 0,
                        data['currency'] as String? ?? 'INR',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

class _PlansList extends StatelessWidget {
  const _PlansList({required this.membership});
  final GymMembership membership;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const Expanded(
              child: Text('Plans define price and membership duration.'),
            ),
            if (membership.can('plans.manage'))
              FilledButton.icon(
                onPressed: () => _editPlan(context),
                icon: const Icon(Icons.add),
                label: const Text('New plan'),
              ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: context.read<GymRepository>().membershipPlans(
            membership.gymId,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _ErrorState(error: snapshot.error);
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.docs.isEmpty) {
              return const _EmptyState(
                icon: Icons.sell_outlined,
                message: 'Create the first membership plan',
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420,
                mainAxisExtent: 190,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final document = snapshot.data!.docs[index];
                final data = document.data();
                final active = data['status'] == 'active';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${data['name']}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Chip(label: Text(active ? 'Active' : 'Inactive')),
                          ],
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
                        Text(
                          '${data['description'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (membership.can('plans.manage'))
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _editPlan(
                                context,
                                planId: document.id,
                                data: data,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit'),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );

  Future<void> _editPlan(
    BuildContext context, {
    String? planId,
    Map<String, dynamic>? data,
  }) async {
    final input = await showDialog<_PlanInput>(
      context: context,
      builder: (_) => _PlanDialog(data: data),
    );
    if (input == null || !context.mounted) return;
    try {
      await context.read<GymRepository>().upsertMembershipPlan(
        gymId: membership.gymId,
        planId: planId,
        name: input.name,
        description: input.description,
        durationDays: input.durationDays,
        priceMinor: input.priceMinor,
        status: input.status,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(planId == null ? 'Plan created.' : 'Plan updated.'),
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
}

class _RenewalDialog extends StatefulWidget {
  const _RenewalDialog({required this.members, required this.plans});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> members;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> plans;

  @override
  State<_RenewalDialog> createState() => _RenewalDialogState();
}

class _RenewalDialogState extends State<_RenewalDialog> {
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController();
  final reference = TextEditingController();
  final notes = TextEditingController();
  late String memberUid = widget.members.first.id;
  late String planId = widget.plans.first.id;
  String method = 'upi';
  DateTime requestedStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    _usePlanPrice();
  }

  @override
  void dispose() {
    amount.dispose();
    reference.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record payment and renewal'),
    content: SizedBox(
      width: 520,
      child: Form(
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
                      (member) => DropdownMenuItem(
                        value: member.id,
                        child: Text(
                          '${member.data()['displayName'] ?? member.data()['email'] ?? member.id}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => memberUid = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: planId,
                decoration: const InputDecoration(labelText: 'Plan'),
                items: widget.plans
                    .map(
                      (plan) => DropdownMenuItem(
                        value: plan.id,
                        child: Text(
                          '${plan.data()['name']} · ${plan.data()['durationDays']} days',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => planId = value!);
                  _usePlanPrice();
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount received',
                  prefixText: '₹ ',
                ),
                validator: (value) {
                  try {
                    BillingAmount.parseMinor(value ?? '');
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const ['upi', 'cash', 'card', 'bank_transfer', 'other']
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_methodLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => method = value!),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Requested start date'),
                subtitle: Text(
                  DateFormat('dd MMM yyyy').format(requestedStart),
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _pickStartDate,
              ),
              const Text(
                'An unexpired membership is extended from its current end date.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reference,
                decoration: const InputDecoration(
                  labelText: 'Transaction/reference (optional)',
                ),
                maxLength: 120,
              ),
              TextFormField(
                controller: notes,
                decoration: const InputDecoration(
                  labelText: 'Internal notes (optional)',
                ),
                maxLength: 500,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Record payment')),
    ],
  );

  void _usePlanPrice() {
    final plan = widget.plans.firstWhere((item) => item.id == planId).data();
    final minor = (plan['priceMinor'] as num?)?.toInt() ?? 0;
    amount.text = (minor / 100).toStringAsFixed(2);
  }

  Future<void> _pickStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: requestedStart,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => requestedStart = selected);
  }

  void _submit() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _RenewalInput(
        memberUid: memberUid,
        planId: planId,
        amountMinor: BillingAmount.parseMinor(amount.text),
        method: method,
        requestedStart: requestedStart,
        reference: reference.text,
        notes: notes.text,
      ),
    );
  }
}

class _PlanDialog extends StatefulWidget {
  const _PlanDialog({this.data});
  final Map<String, dynamic>? data;

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  final formKey = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.data?['name'] as String?,
  );
  late final description = TextEditingController(
    text: widget.data?['description'] as String?,
  );
  late final duration = TextEditingController(
    text: '${widget.data?['durationDays'] ?? 30}',
  );
  late final price = TextEditingController(
    text: (((widget.data?['priceMinor'] as num?)?.toInt() ?? 0) / 100)
        .toStringAsFixed(2),
  );
  late String status = widget.data?['status'] as String? ?? 'active';

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    duration.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.data == null ? 'Create membership plan' : 'Edit plan'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Plan name'),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter a plan name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLength: 300,
                maxLines: 2,
              ),
              TextFormField(
                controller: duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration in days',
                ),
                validator: (value) {
                  final days = int.tryParse(value ?? '');
                  return days == null || days < 1 || days > 3660
                      ? 'Enter 1–3660 days'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixText: '₹ ',
                ),
                validator: (value) {
                  try {
                    BillingAmount.parseMinor(value ?? '');
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Availability'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (value) => setState(() => status = value!),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save plan')),
    ],
  );

  void _submit() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _PlanInput(
        name: name.text.trim(),
        description: description.text.trim(),
        durationDays: int.parse(duration.text),
        priceMinor: BillingAmount.parseMinor(price.text),
        status: status,
      ),
    );
  }
}

class _ListFilters extends StatelessWidget {
  const _ListFilters({
    required this.hint,
    required this.value,
    required this.options,
    required this.onSearch,
    required this.onFilter,
  });

  final String hint;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFilter;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 360,
          child: TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: hint,
            ),
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            initialValue: value,
            items: options.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (selected) => onFilter(selected!),
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (color ?? Theme.of(context).colorScheme.primary)
                .withValues(alpha: .12),
            foregroundColor: color ?? Theme.of(context).colorScheme.primary,
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                Text(label),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.health});
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
      side: BorderSide(color: color.withValues(alpha: .5)),
      backgroundColor: color.withValues(alpha: .1),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(message, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('Unable to load billing data: $error'));
}

class _RenewalInput {
  const _RenewalInput({
    required this.memberUid,
    required this.planId,
    required this.amountMinor,
    required this.method,
    required this.requestedStart,
    required this.reference,
    required this.notes,
  });
  final String memberUid;
  final String planId;
  final int amountMinor;
  final String method;
  final DateTime requestedStart;
  final String reference;
  final String notes;
}

class _PlanInput {
  const _PlanInput({
    required this.name,
    required this.description,
    required this.durationDays,
    required this.priceMinor,
    required this.status,
  });
  final String name;
  final String description;
  final int durationDays;
  final int priceMinor;
  final String status;
}

String _money(int amountMinor, String currency) => NumberFormat.simpleCurrency(
  name: currency,
  decimalDigits: amountMinor % 100 == 0 ? 0 : 2,
).format(amountMinor / 100);

String _methodLabel(Object? method) => switch (method) {
  'upi' => 'UPI',
  'cash' => 'Cash',
  'card' => 'Card',
  'bank_transfer' => 'Bank transfer',
  _ => 'Other',
};

String _initial(Object? value) {
  final text = '$value'.trim();
  return text.isEmpty ? '?' : text.characters.first.toUpperCase();
}
