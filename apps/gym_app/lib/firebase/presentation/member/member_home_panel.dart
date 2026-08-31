import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_core/gym_core.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../data/gym_repository.dart';
import '../../domain/exercise_guide.dart';
import '../../domain/member_gym_service.dart';
import '../shared/responsive_padding.dart';
import '../workspace/member_billing_panel.dart';
import 'exercise_media_image.dart';
import 'member_training_panel.dart';

class MemberHomePanel extends StatefulWidget {
  const MemberHomePanel({
    required this.membership,
    this.fitnessScope,
    this.onOpenGymServices,
    this.onOpenSupport,
    super.key,
  });

  final GymMembership membership;
  final FitnessScope? fitnessScope;
  final VoidCallback? onOpenGymServices;
  final VoidCallback? onOpenSupport;

  @override
  State<MemberHomePanel> createState() => _MemberHomePanelState();
}

class _MemberHomePanelState extends State<MemberHomePanel>
    with AutomaticKeepAliveClientMixin {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> profileStream;

  GymMembership get membership => widget.membership;

  @override
  void initState() {
    super.initState();
    profileStream = _profileStream();
  }

  @override
  void didUpdateWidget(covariant MemberHomePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.membership.gymId != membership.gymId ||
        oldWidget.membership.uid != membership.uid) {
      profileStream = _profileStream();
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream() => context
      .read<GymRepository>()
      .memberProfile(membership.gymId, membership.uid);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profileStream,
      builder: (context, snapshot) {
        final profile = snapshot.data?.data() ?? const <String, dynamic>{};
        final profileLoaded = snapshot.hasData;
        final goal = _recommendedGoal(profile);
        final plan = exercisesForGoal(goal, limit: 5);
        final gymServices = availableMemberGymServices(
          membership: membership,
          attendancePlatformEnabled: AppFeatureFlags.attendanceQr,
        );
        return ListView(
          key: PageStorageKey(
            'member-home-${membership.gymId}-${membership.uid}',
          ),
          padding: memberPanelPadding(context),
          children: [
            Text(
              'Ready to move?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(membership.tagline),
            if (profileLoaded && profile['onboardingCompletedAt'] == null)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.auto_awesome),
                  title: Text('Personalize your recommendations'),
                  subtitle: Text(
                    'Open Profile and complete your goals, experience and available equipment.',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            MemberSubscriptionBanner(membership: membership),
            if (widget.onOpenGymServices != null && gymServices.isNotEmpty) ...[
              const SizedBox(height: 14),
              _GymServicesCard(
                membership: membership,
                services: gymServices,
                onOpen: widget.onOpenGymServices!,
              ),
            ],
            const SizedBox(height: 20),
            _TodayWorkoutCard(
              exercises: plan,
              onStart: () => openGuidedWorkout(
                context,
                scope: widget.fitnessScope ?? FitnessScope.gym(membership),
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
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onOpenSupport,
              ),
            ),
          ],
        );
      },
    );
  }

  TrainingGoal _recommendedGoal(Map<String, dynamic> profile) {
    final goals = Set<String>.from(
      profile['fitnessGoals'] as List? ?? const [],
    );
    for (final goal in TrainingGoal.values) {
      if (goals.contains(goal.name)) return goal;
    }
    return TrainingGoal.improveFitness;
  }
}

class _GymServicesCard extends StatelessWidget {
  const _GymServicesCard({
    required this.membership,
    required this.services,
    required this.onOpen,
  });

  final GymMembership membership;
  final List<MemberGymService> services;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              child: const Icon(Icons.storefront_outlined),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'At ${membership.gymName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final service in services)
                        Chip(
                          avatar: Icon(
                            service == MemberGymService.attendance
                                ? Icons.qr_code_scanner
                                : Icons.event_available_outlined,
                            size: 17,
                          ),
                          label: Text(
                            service == MemberGymService.attendance
                                ? 'Check in'
                                : 'Classes',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
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

class _MemberTrainingSummary extends StatefulWidget {
  const _MemberTrainingSummary({required this.membership});

  final GymMembership membership;

  @override
  State<_MemberTrainingSummary> createState() => _MemberTrainingSummaryState();
}

class _MemberTrainingSummaryState extends State<_MemberTrainingSummary> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> workoutLogsStream;

  GymMembership get membership => widget.membership;

  @override
  void initState() {
    super.initState();
    workoutLogsStream = _stream();
  }

  @override
  void didUpdateWidget(covariant _MemberTrainingSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.membership.gymId != membership.gymId ||
        oldWidget.membership.uid != membership.uid) {
      workoutLogsStream = _stream();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() =>
      context.read<GymRepository>().recentForMember(
        membership.gymId,
        'workout_logs',
        membership.uid,
        limit: 30,
      );

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: workoutLogsStream,
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

class _GymAnnouncements extends StatefulWidget {
  const _GymAnnouncements({required this.membership});

  final GymMembership membership;

  @override
  State<_GymAnnouncements> createState() => _GymAnnouncementsState();
}

class _GymAnnouncementsState extends State<_GymAnnouncements> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> announcementsStream;

  GymMembership get membership => widget.membership;

  @override
  void initState() {
    super.initState();
    announcementsStream = _stream();
  }

  @override
  void didUpdateWidget(covariant _GymAnnouncements oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.membership.gymId != membership.gymId) {
      announcementsStream = _stream();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() => context
      .read<GymRepository>()
      .recent(membership.gymId, 'announcements', limit: 3);

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: announcementsStream,
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
