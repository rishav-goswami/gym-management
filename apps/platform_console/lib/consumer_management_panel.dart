import 'package:flutter/material.dart';

import 'platform_gym_repository.dart';

class ConsumerManagementPanel extends StatefulWidget {
  const ConsumerManagementPanel({super.key});

  @override
  State<ConsumerManagementPanel> createState() =>
      _ConsumerManagementPanelState();
}

class _ConsumerManagementPanelState extends State<ConsumerManagementPanel> {
  final repository = PlatformGymRepository();
  late Future<List<Map<String, dynamic>>> consumers = repository
      .listConsumers();

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: consumers,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text('Unable to load consumers: ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final rows = snapshot.data!;
      if (rows.isEmpty) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Consumer accounts will appear after registration.'),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (consumer) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    '${consumer['displayName'] ?? consumer['email'] ?? '?'}'
                        .characters
                        .first
                        .toUpperCase(),
                  ),
                ),
                title: Text(
                  '${consumer['displayName'] ?? consumer['email'] ?? 'Consumer'}',
                ),
                subtitle: Text(
                  '${consumer['email'] ?? consumer['phone'] ?? consumer['uid']} · '
                  '${consumer['planId'] ?? 'free'} · '
                  '${consumer['onboardingCompleted'] == true ? 'onboarded' : 'not onboarded'}',
                ),
                trailing: Chip(
                  label: Text('${consumer['status'] ?? 'active'}'),
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => _ConsumerDialog(
                    consumer: consumer,
                    repository: repository,
                    onChanged: _refresh,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  void _refresh() => setState(() => consumers = repository.listConsumers());
}

class _ConsumerDialog extends StatefulWidget {
  const _ConsumerDialog({
    required this.consumer,
    required this.repository,
    required this.onChanged,
  });

  final Map<String, dynamic> consumer;
  final PlatformGymRepository repository;
  final VoidCallback onChanged;

  @override
  State<_ConsumerDialog> createState() => _ConsumerDialogState();
}

class _ConsumerDialogState extends State<_ConsumerDialog> {
  final reason = TextEditingController();
  final overrides = <String, bool>{
    'routines': true,
    'workoutLogging': true,
    'progress': true,
    'progressPhotos': true,
    'gymConnections': true,
  };
  bool working = false;

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = '${widget.consumer['status'] ?? 'active'}';
    return AlertDialog(
      title: Text('${widget.consumer['displayName'] ?? 'Consumer'}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.consumer['email'] ?? widget.consumer['phone'] ?? ''}',
              ),
              const SizedBox(height: 8),
              const Text(
                'Private fitness records are unavailable here. Support access requires a reason, expires in 15 minutes and is audited.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: reason,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Required support reason',
                  hintText: 'Describe the issue being investigated',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: working ? null : _support,
                icon: const Icon(Icons.support_agent),
                label: const Text('Open audited account diagnostics'),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Entitlement overrides'),
                subtitle: const Text('Free core features default to enabled'),
                children: [
                  for (final entry in overrides.entries)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: entry.value,
                      title: Text(entry.key),
                      onChanged: working
                          ? null
                          : (value) =>
                                setState(() => overrides[entry.key] = value),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: working ? null : _saveEntitlements,
                      child: const Text('Apply overrides'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: working ? null : () => _setStatus(status),
                icon: Icon(
                  status == 'suspended' ? Icons.check_circle : Icons.block,
                ),
                label: Text(
                  status == 'suspended'
                      ? 'Reactivate account'
                      : 'Suspend account',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: working ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _support() async {
    if (reason.text.trim().length < 12) {
      _message('Enter a clear support reason of at least 12 characters.');
      return;
    }
    setState(() => working = true);
    try {
      final result = await widget.repository.openConsumerSupport(
        uid: '${widget.consumer['uid']}',
        reason: reason.text.trim(),
        categories: const [
          'account',
          'onboarding',
          'sharing',
          'memberships',
          'usage',
        ],
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Audited diagnostics'),
          content: SizedBox(width: 600, child: SelectableText(_pretty(result))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _message('Support access failed: $error');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _setStatus(String current) async {
    if (reason.text.trim().length < 8) {
      _message('Enter a reason of at least 8 characters first.');
      return;
    }
    setState(() => working = true);
    try {
      await widget.repository.setConsumerStatus(
        uid: '${widget.consumer['uid']}',
        status: current == 'suspended' ? 'active' : 'suspended',
        reason: reason.text.trim(),
      );
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      _message('Status update failed: $error');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _saveEntitlements() async {
    if (reason.text.trim().length < 8) {
      _message('Enter a reason of at least 8 characters first.');
      return;
    }
    setState(() => working = true);
    try {
      await widget.repository.setConsumerEntitlementOverrides(
        uid: '${widget.consumer['uid']}',
        overrides: overrides,
        reason: reason.text.trim(),
      );
      _message('Entitlement overrides saved.');
    } catch (error) {
      _message('Entitlement update failed: $error');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _pretty(Object? value, [int depth = 0]) {
    if (value is Map) {
      return value.entries
          .map(
            (entry) =>
                '${'  ' * depth}${entry.key}: ${_pretty(entry.value, depth + 1)}',
          )
          .join('\n');
    }
    if (value is List) {
      return '[${value.map((item) => _pretty(item, depth + 1)).join(', ')}]';
    }
    return '$value';
  }
}
