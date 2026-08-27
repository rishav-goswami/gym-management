import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'platform_gym_repository.dart';

class PlatformInsightsPanel extends StatefulWidget {
  const PlatformInsightsPanel({super.key});

  @override
  State<PlatformInsightsPanel> createState() => _PlatformInsightsPanelState();
}

class _PlatformInsightsPanelState extends State<PlatformInsightsPanel> {
  final repository = PlatformGymRepository();
  late Future<Map<String, dynamic>> dashboard = repository.loadDashboard();

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: dashboard,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('Platform overview unavailable'),
            subtitle: Text('${snapshot.error}'),
            trailing: IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final totals = Map<String, dynamic>.from(
        snapshot.data!['totals'] as Map? ?? const {},
      );
      final features = (snapshot.data!['features'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final maxEvents = features.fold<num>(1, (max, item) {
        final value = item['totalEvents'] as num? ?? 0;
        return value > max ? value : max;
      });
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Platform overview',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Refresh metrics',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const Text(
            'Server-calculated tenant and audience totals. Feature events are anonymous aggregate counters.',
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.sizeOf(context).width > 1000 ? 4 : 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _Metric(
                label: 'Gyms',
                value: totals['gyms'] ?? 0,
                icon: Icons.business,
              ),
              _Metric(
                label: 'Active user seats',
                value: totals['users'] ?? 0,
                icon: Icons.people,
              ),
              _Metric(
                label: 'Members',
                value: totals['members'] ?? 0,
                icon: Icons.fitness_center,
              ),
              _Metric(
                label: 'Trainers',
                value: totals['trainers'] ?? 0,
                icon: Icons.sports,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Feature relevance by audience',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (features.isEmpty)
            const Card(
              child: ListTile(title: Text('No feature usage recorded yet')),
            )
          else
            ...features.take(10).map((feature) {
              final events = feature['totalEvents'] as num? ?? 0;
              final feedbackCount = feature['feedbackCount'] as num? ?? 0;
              final ratingTotal = feature['ratingTotal'] as num? ?? 0;
              final average = feedbackCount == 0
                  ? null
                  : ratingTotal / feedbackCount;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _label('${feature['id']}'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '$events opens${average == null ? '' : ' · ${average.toStringAsFixed(1)}★'}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: events / maxEvents),
                      const SizedBox(height: 6),
                      Text(
                        'Members ${feature['audience_member'] ?? 0} · Trainers ${feature['audience_trainer'] ?? 0} · Owners ${feature['audience_owner'] ?? 0} · Staff ${(feature['audience_manager'] as num? ?? 0) + (feature['audience_receptionist'] as num? ?? 0)}',
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          Text(
            'Latest product feedback',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const _FeedbackList(),
        ],
      );
    },
  );

  void _refresh() => setState(() => dashboard = repository.loadDashboard());

  String _label(String value) => value
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .replaceAll('_', ' ')
      .trim();
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final Object value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$value', style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ],
          ),
        ],
      ),
    ),
  );
}

class _FeedbackList extends StatelessWidget {
  const _FeedbackList();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('platform_feedback')
            .orderBy('createdAt', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Unable to load feedback: ${snapshot.error}');
          }
          final documents = snapshot.data?.docs ?? const [];
          if (documents.isEmpty) {
            return const Card(
              child: ListTile(title: Text('No feedback submitted yet')),
            );
          }
          return Column(
            children: documents.map((document) {
              final item = document.data();
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${item['rating'] ?? '–'}★'),
                  ),
                  title: Text(
                    '${item['featureId'] ?? 'App'} · ${item['role'] ?? 'user'}',
                  ),
                  subtitle: Text('${item['message'] ?? ''}'),
                  trailing: Text('${item['gymId'] ?? ''}'),
                ),
              );
            }).toList(),
          );
        },
      );
}
