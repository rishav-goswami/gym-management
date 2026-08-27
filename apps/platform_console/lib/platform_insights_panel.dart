import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'platform_gym_repository.dart';

enum PlatformInsightsView { overview, analytics, feedback }

class PlatformInsightsPanel extends StatefulWidget {
  const PlatformInsightsPanel({required this.view, super.key});

  final PlatformInsightsView view;

  @override
  State<PlatformInsightsPanel> createState() => _PlatformInsightsPanelState();
}

class _PlatformInsightsPanelState extends State<PlatformInsightsPanel> {
  final repository = PlatformGymRepository();
  late Future<Map<String, dynamic>> dashboard = repository.loadDashboard();

  @override
  Widget build(BuildContext context) {
    if (widget.view == PlatformInsightsView.feedback) {
      return const _FeedbackWorkspace();
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: dashboard,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorCard(error: snapshot.error, onRetry: _refresh);
        }
        if (!snapshot.hasData) return const _LoadingDashboard();
        final totals = Map<String, dynamic>.from(
          snapshot.data!['totals'] as Map? ?? const {},
        );
        final features = (snapshot.data!['features'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        return widget.view == PlatformInsightsView.overview
            ? _Overview(totals: totals, features: features, onRefresh: _refresh)
            : _FeatureAnalytics(features: features, onRefresh: _refresh);
      },
    );
  }

  void _refresh() => setState(() => dashboard = repository.loadDashboard());
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.totals,
    required this.features,
    required this.onRefresh,
  });
  final Map<String, dynamic> totals;
  final List<Map<String, dynamic>> features;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final activeGyms = totals['activeGyms'] as num? ?? 0;
    final trialGyms = totals['trialGyms'] as num? ?? 0;
    final gyms = totals['gyms'] as num? ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh metrics'),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050
                ? 4
                : constraints.maxWidth >= 620
                ? 2
                : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              childAspectRatio: columns == 1 ? 3.2 : 2.15,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              children: [
                _MetricCard(
                  label: 'Gym tenants',
                  value: gyms,
                  supporting: '$activeGyms active · $trialGyms trial',
                  icon: Icons.business,
                  color: Colors.indigo,
                ),
                _MetricCard(
                  label: 'Active user seats',
                  value: totals['users'] ?? 0,
                  supporting: 'Across all tenant memberships',
                  icon: Icons.people_alt_outlined,
                  color: Colors.teal,
                ),
                _MetricCard(
                  label: 'Members',
                  value: totals['members'] ?? 0,
                  supporting: 'Active member seats',
                  icon: Icons.fitness_center,
                  color: Colors.orange,
                ),
                _MetricCard(
                  label: 'Trainers',
                  value: totals['trainers'] ?? 0,
                  supporting: 'Active trainer seats',
                  icon: Icons.sports_outlined,
                  color: Colors.purple,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adoption snapshot',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Top features by counted opens. Use Feature analytics for audience comparisons.',
                ),
                const SizedBox(height: 18),
                if (features.isEmpty)
                  const _EmptyState(
                    icon: Icons.query_stats,
                    title: 'Usage data will appear here',
                    message:
                        'Counters begin after users navigate through the newly deployed app.',
                  )
                else
                  for (final feature in features.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_featureLabel('${feature['id']}')),
                          ),
                          Text('${feature['totalEvents'] ?? 0} opens'),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureAnalytics extends StatelessWidget {
  const _FeatureAnalytics({required this.features, required this.onRefresh});
  final List<Map<String, dynamic>> features;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final maxEvents = features.fold<num>(1, (maximum, item) {
      final value = item['totalEvents'] as num? ?? 0;
      return value > maximum ? value : maximum;
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to read this graph',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Bar length compares opens; audience chips show who used each feature.',
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (features.isEmpty)
          const _EmptyState(
            icon: Icons.query_stats,
            title: 'No feature activity yet',
            message:
                'Open counts will appear after members, trainers and owners use the updated app.',
          )
        else
          ...features.take(20).map((feature) {
            final events = feature['totalEvents'] as num? ?? 0;
            final feedbackCount = feature['feedbackCount'] as num? ?? 0;
            final ratingTotal = feature['ratingTotal'] as num? ?? 0;
            final average = feedbackCount == 0
                ? null
                : ratingTotal / feedbackCount;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          child: Icon(_featureIcon('${feature['id']}')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _featureLabel('${feature['id']}'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                average == null
                                    ? 'No ratings yet'
                                    : '${average.toStringAsFixed(1)} / 5 from $feedbackCount ratings',
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$events opens',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: events / maxEvents,
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _AudienceChip(
                          label: 'Members',
                          value: feature['audience_member'],
                          color: Colors.orange,
                        ),
                        _AudienceChip(
                          label: 'Trainers',
                          value: feature['audience_trainer'],
                          color: Colors.purple,
                        ),
                        _AudienceChip(
                          label: 'Owners',
                          value: feature['audience_owner'],
                          color: Colors.indigo,
                        ),
                        _AudienceChip(
                          label: 'Staff',
                          value:
                              (feature['audience_manager'] as num? ?? 0) +
                              (feature['audience_receptionist'] as num? ?? 0) +
                              (feature['audience_accountant'] as num? ?? 0),
                          color: Colors.teal,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _FeedbackWorkspace extends StatefulWidget {
  const _FeedbackWorkspace();
  @override
  State<_FeedbackWorkspace> createState() => _FeedbackWorkspaceState();
}

class _FeedbackWorkspaceState extends State<_FeedbackWorkspace> {
  String role = 'all';
  String feature = 'all';

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('platform_feedback')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _ErrorCard(error: snapshot.error);
      if (!snapshot.hasData) return const _LoadingDashboard();
      final all = snapshot.data!.docs;
      final roles = <String>{
        for (final item in all) '${item.data()['role'] ?? 'member'}',
      };
      final features = <String>{
        for (final item in all) '${item.data()['featureId'] ?? 'app'}',
      };
      final filtered = all.where((item) {
        final data = item.data();
        return (role == 'all' || data['role'] == role) &&
            (feature == 'all' || data['featureId'] == feature);
      }).toList();
      final average = filtered.isEmpty
          ? 0.0
          : filtered.fold<num>(
                  0,
                  (total, item) => total + (item.data()['rating'] as num? ?? 0),
                ) /
                filtered.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: constraints.maxWidth >= 720 ? 3 : 1,
              childAspectRatio: constraints.maxWidth >= 720 ? 2.5 : 3.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _MetricCard(
                  label: 'Responses',
                  value: filtered.length,
                  supporting: 'Latest 100 submissions',
                  icon: Icons.forum_outlined,
                  color: Colors.indigo,
                ),
                _MetricCard(
                  label: 'Average rating',
                  value: filtered.isEmpty ? '—' : average.toStringAsFixed(1),
                  supporting: 'Out of 5',
                  icon: Icons.star_outline,
                  color: Colors.amber.shade800,
                ),
                _MetricCard(
                  label: 'Audience groups',
                  value: roles.length,
                  supporting: 'Roles represented',
                  icon: Icons.groups_outlined,
                  color: Colors.teal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(
                        labelText: 'Audience role',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All audiences'),
                        ),
                        ...roles.map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_featureLabel(value)),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => role = value!),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      initialValue: feature,
                      decoration: const InputDecoration(
                        labelText: 'Feature',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All features'),
                        ),
                        ...features.map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_featureLabel(value)),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => feature = value!),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const _EmptyState(
              icon: Icons.mark_chat_unread_outlined,
              title: 'No feedback matches these filters',
              message:
                  'Member, trainer and owner submissions will appear here.',
            )
          else
            ...filtered.map((document) {
              final item = document.data();
              final rating = (item['rating'] as num? ?? 0).toInt();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(child: Text('$rating')),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _featureLabel(
                                    '${item['featureId'] ?? 'App'}',
                                  ),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Chip(label: Text('${item['role'] ?? 'user'}')),
                                Text('★' * rating),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('${item['message'] ?? ''}'),
                            const SizedBox(height: 8),
                            Text(
                              'Gym ${item['gymId'] ?? 'unknown'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.supporting,
    required this.icon,
    required this.color,
  });
  final String label;
  final Object value;
  final String supporting;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  supporting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AudienceChip extends StatelessWidget {
  const _AudienceChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final Object? value;
  final Color color;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: CircleAvatar(backgroundColor: color, radius: 5),
    label: Text('$label ${value ?? 0}'),
  );
}

class _LoadingDashboard extends StatelessWidget {
  const _LoadingDashboard();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          LinearProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading platform data…'),
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, this.onRetry});
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.error_outline),
      title: const Text('Unable to load this workspace'),
      subtitle: Text('$error'),
      trailing: onRetry == null
          ? null
          : IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

String _featureLabel(String value) => value
    .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
    .replaceAll('_', ' ')
    .trim();

IconData _featureIcon(String feature) => switch (feature) {
  'training' => Icons.fitness_center,
  'progress' => Icons.query_stats,
  'billing' => Icons.payments_outlined,
  'attendance' => Icons.qr_code_scanner,
  'classes' => Icons.event_available_outlined,
  'chat' => Icons.chat_bubble_outline,
  'members' => Icons.groups_outlined,
  'profile' => Icons.person_outline,
  _ => Icons.widgets_outlined,
};
