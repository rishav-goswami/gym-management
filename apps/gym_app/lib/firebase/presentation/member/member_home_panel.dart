import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_core/gym_core.dart';

import '../../data/gym_repository.dart';
import '../../domain/exercise_guide.dart';
import '../workspace/member_billing_panel.dart';
import 'exercise_media_image.dart';
import 'member_training_panel.dart';

class MemberHomePanel extends StatelessWidget {
  const MemberHomePanel({required this.membership, super.key});

  final GymMembership membership;

  @override
  Widget build(BuildContext context) {
    const goal = TrainingGoal.improveFitness;
    final plan = exercisesForGoal(goal, limit: 5);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Ready to move?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(membership.tagline),
        const SizedBox(height: 16),
        MemberSubscriptionBanner(membership: membership),
        const SizedBox(height: 20),
        _TodayWorkoutCard(
          exercises: plan,
          onStart: () => openGuidedWorkout(
            context,
            membership: membership,
            goal: goal,
            exercises: plan,
          ),
        ),
        const SizedBox(height: 20),
        _MemberTrainingSummary(membership: membership),
        const SizedBox(height: 20),
        _GymAnnouncements(membership: membership),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.support_agent)),
            title: const Text('Need help with your plan?'),
            subtitle: const Text(
              'Open Support to message your trainer or gym team before changing a prescribed routine.',
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayWorkoutCard extends StatelessWidget {
  const _TodayWorkoutCard({required this.exercises, required this.onStart});

  final List<ExerciseGuide> exercises;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExerciseMediaImage(
                exercise: exercises.first,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.35),
                colorBlendMode: BlendMode.darken,
                errorIconSize: 64,
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'TODAY\'S WORKOUT',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Full-body foundation',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '${exercises.length} exercises · about 35 minutes',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'A balanced session you can start now. Your trainer plan remains available in Training.',
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MemberTrainingSummary extends StatelessWidget {
  const _MemberTrainingSummary({required this.membership});

  final GymMembership membership;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: context.read<GymRepository>().recentForMember(
      membership.gymId,
      'workout_logs',
      membership.uid,
      limit: 30,
    ),
    builder: (context, snapshot) {
      final now = DateTime.now();
      final documents = snapshot.data?.docs ?? const [];
      final thisWeek = documents
          .where((document) {
            final value = document.data()['completedAt'];
            return value is Timestamp &&
                now.difference(value.toDate()).inDays < 7;
          })
          .toList(growable: false);
      var completedSets = 0;
      for (final document in thisWeek) {
        final exercises = document.data()['exercises'];
        if (exercises is! List) continue;
        for (final exercise in exercises) {
          if (exercise is Map) {
            completedSets += (exercise['completedSets'] as num?)?.toInt() ?? 0;
          }
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your week', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.event_available,
                  value: '${thisWeek.length}',
                  label: 'Workouts',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  icon: Icons.repeat,
                  value: '$completedSets',
                  label: 'Sets completed',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  icon: Icons.local_fire_department_outlined,
                  value: thisWeek.isEmpty ? 'Start' : '${thisWeek.length} day',
                  label: 'Momentum',
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, maxLines: 2),
        ],
      ),
    ),
  );
}

class _GymAnnouncements extends StatelessWidget {
  const _GymAnnouncements({required this.membership});

  final GymMembership membership;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: context.read<GymRepository>().recent(
          membership.gymId,
          'announcements',
          limit: 3,
        ),
        builder: (context, snapshot) {
          final announcements = snapshot.data?.docs ?? const [];
          if (announcements.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'From your gym',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...announcements.map((document) {
                final data = document.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.campaign_outlined),
                    title: Text(data['title'] as String? ?? 'Gym update'),
                    subtitle: Text(
                      data['body'] as String? ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }),
            ],
          );
        },
      );
}
