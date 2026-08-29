import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_core/gym_core.dart';

import '../../data/gym_repository.dart';
import '../../logic/session_cubit.dart';
import '../../domain/exercise_guide.dart';
import '../../domain/workout_draft.dart';
import 'member_custom_workouts.dart';
import 'exercise_media_image.dart';
import '../support/support_hub_screen.dart';

Future<void> openGuidedWorkout(
  BuildContext context, {
  required FitnessScope scope,
  required TrainingGoal goal,
  required List<ExerciseGuide> exercises,
}) async {
  final draft = await WorkoutDraftStore.load(scope.uid, scope.draftKey);
  final canResume =
      draft?.matches(
        expectedGymId: scope.draftKey,
        expectedUid: scope.uid,
        expectedGoal: goal.name,
        expectedExerciseIds: exercises.map((exercise) => exercise.id).toList(),
      ) ??
      false;
  WorkoutDraft? selectedDraft;
  if (canResume && context.mounted) {
    final resume = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restore),
        title: const Text('Resume your workout?'),
        content: const Text(
          'Your completed sets and working weights were saved on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Start over'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
    if (resume == true) {
      selectedDraft = draft;
    } else {
      await WorkoutDraftStore.clear(scope.uid, scope.draftKey);
    }
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => GuidedWorkoutScreen(
        scope: scope,
        goal: goal,
        exercises: exercises,
        initialDraft: selectedDraft,
      ),
    ),
  );
}

class MemberTrainingPanel extends StatefulWidget {
  const MemberTrainingPanel({required this.scope, super.key});

  final FitnessScope scope;

  @override
  State<MemberTrainingPanel> createState() => _MemberTrainingPanelState();
}

class _MemberTrainingPanelState extends State<MemberTrainingPanel> {
  final _search = TextEditingController();
  TrainingGoal _goal = TrainingGoal.buildMuscle;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scope.isPersonal) {
      return _buildContent(context, exerciseGuides);
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: context.read<GymRepository>().tenantExercises(
        widget.scope.gymId!,
      ),
      builder: (context, snapshot) {
        final tenant =
            snapshot.data?.docs
                .map(
                  (document) => ExerciseGuide.fromTenant(
                    widget.scope.gymId!,
                    document.id,
                    document.data(),
                  ),
                )
                .toList() ??
            const <ExerciseGuide>[];
        return _buildContent(context, [...exerciseGuides, ...tenant]);
      },
    );
  }

  Widget _buildContent(BuildContext context, List<ExerciseGuide> catalog) {
    final query = _search.text.trim().toLowerCase();
    final filtered = catalog
        .where((exercise) {
          final matchesGoal = exercise.goals.contains(_goal);
          final matchesQuery =
              query.isEmpty ||
              exercise.name.toLowerCase().contains(query) ||
              exercise.primaryMuscle.toLowerCase().contains(query) ||
              exercise.secondaryMuscles.any(
                (muscle) => muscle.toLowerCase().contains(query),
              ) ||
              exercise.movementPattern.toLowerCase().contains(query) ||
              exercise.equipment.toLowerCase().contains(query);
          return matchesGoal && matchesQuery;
        })
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Your training',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'Follow your trainer plan or choose a guided session for your goal.',
        ),
        const SizedBox(height: 20),
        _GoalPlanCard(goal: _goal, onStart: () => _startWorkout(context)),
        const SizedBox(height: 20),
        MemberRoutinesSection(scope: widget.scope),
        if (widget.scope.isPersonal) ...[
          const SizedBox(height: 24),
          _ConnectedGymAssignments(
            memberships: context
                .watch<SessionCubit>()
                .state
                .memberships
                .where((item) => item.role == GymRole.member)
                .toList(),
            personalScope: widget.scope,
          ),
        ],
        if (!widget.scope.isPersonal) ...[
          const SizedBox(height: 24),
          _TrainerAssignments(membership: widget.scope.membership!),
        ],
        const SizedBox(height: 24),
        Text(
          'Choose your target',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: TrainingGoal.values
                .map(
                  (goal) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(goal.label),
                      selected: goal == _goal,
                      onSelected: (_) => setState(() => _goal = goal),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search exercise, muscle, or equipment',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _search.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${_goal.label} exercises',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(_goal.description),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 3
                : constraints.maxWidth >= 620
                ? 2
                : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 286,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemBuilder: (_, index) => _ExerciseCard(
                exercise: filtered[index],
                onTap: () => _showExercise(context, filtered[index]),
              ),
            );
          },
        ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No exercises match this search.')),
          ),
        const SizedBox(height: 20),
        const _TrainingSafetyNote(),
      ],
    );
  }

  Future<void> _startWorkout(BuildContext context) => openGuidedWorkout(
    context,
    scope: widget.scope,
    goal: _goal,
    exercises: exercisesForGoal(_goal, limit: 5),
  );

  Future<void> _showExercise(BuildContext context, ExerciseGuide exercise) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => _ExerciseDetails(
          exercise: exercise,
          onAskSupport: () {
            Navigator.pop(sheetContext);
            final membership = context
                .read<SessionCubit>()
                .state
                .memberAppMembership;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SupportHubScreen(
                  membership: membership,
                  initialRoute: membership == null ? 'platform' : 'trainer',
                  supportContext: {
                    'type': 'exercise',
                    'id': exercise.id,
                    'label': exercise.name,
                    'catalogVersion': 'v1',
                  },
                ),
              ),
            );
          },
          onVariationTap: (variation) {
            Navigator.pop(sheetContext);
            Future<void>.delayed(Duration.zero, () {
              if (context.mounted) _showExercise(context, variation);
            });
          },
        ),
      );
}

class _GoalPlanCard extends StatelessWidget {
  const _GoalPlanCard({required this.goal, required this.onStart});

  final TrainingGoal goal;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final exercises = exercisesForGoal(goal, limit: 5);
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RECOMMENDED TODAY'),
            const SizedBox(height: 6),
            Text(
              '${goal.label} session',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text('${exercises.length} exercises · approximately 35 minutes'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: exercises
                  .map((exercise) => Chip(label: Text(exercise.name)))
                  .toList(growable: false),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start guided workout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerAssignments extends StatelessWidget {
  const _TrainerAssignments({required this.membership});

  final GymMembership membership;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: context.read<GymRepository>().recentForMember(
      membership.gymId,
      'workout_assignments',
      membership.uid,
      limit: 3,
    ),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const SizedBox.shrink();
      }
      final assignments = snapshot.data?.docs ?? const [];
      if (assignments.isEmpty) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('No trainer plan yet'),
            subtitle: const Text(
              'You can use a guided workout now and ask your trainer for a personal plan.',
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'From your trainer',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...assignments.map((document) {
            final data = document.data();
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.assignment)),
                title: Text(data['title'] as String? ?? 'Trainer workout'),
                subtitle: Text(
                  data['routine'] as String? ??
                      'Open the plan for trainer notes.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(data['title'] as String? ?? 'Trainer workout'),
                    content: SelectableText(
                      data['routine'] as String? ?? 'No notes supplied.',
                    ),
                    actions: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SupportHubScreen(
                                membership: membership,
                                initialRoute: 'trainer',
                                supportContext: {
                                  'type': 'assignment',
                                  'id': document.id,
                                  'label': data['title'] ?? 'Trainer workout',
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Ask trainer'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      );
    },
  );
}

class _ConnectedGymAssignments extends StatelessWidget {
  const _ConnectedGymAssignments({
    required this.memberships,
    required this.personalScope,
  });

  final List<GymMembership> memberships;
  final FitnessScope personalScope;

  @override
  Widget build(BuildContext context) {
    if (memberships.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('From your gyms', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
          'Assignments appear here, but results stay private unless you choose to share summaries.',
        ),
        const SizedBox(height: 8),
        for (final membership in memberships)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: context.read<GymRepository>().recentForMember(
              membership.gymId,
              'workout_assignments',
              membership.uid,
              limit: 3,
            ),
            builder: (context, snapshot) {
              final assignments = snapshot.data?.docs ?? const [];
              return Column(
                children: assignments
                    .map(
                      (document) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.assignment_outlined),
                          ),
                          title: Text(
                            document.data()['title'] as String? ??
                                'Trainer workout',
                          ),
                          subtitle: Text(
                            '${membership.gymName} · ${document.data()['routine'] ?? 'Open trainer notes'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.play_arrow),
                          onTap: () => _showAssignmentActions(
                            context,
                            membership,
                            document,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Future<void> _showAssignmentActions(
    BuildContext context,
    GymMembership membership,
    QueryDocumentSnapshot<Map<String, dynamic>> assignment,
  ) async {
    final data = assignment.data();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                data['title'] as String? ?? 'Trainer workout',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(data['routine'] as String? ?? 'No trainer notes supplied.'),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'start'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start workout'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'ask'),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Ask trainer about this plan'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'start') {
      await _startAssignment(context, membership, assignment);
    } else if (action == 'ask') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SupportHubScreen(
            membership: membership,
            initialRoute: 'trainer',
            supportContext: {
              'type': 'assignment',
              'id': assignment.id,
              'label': data['title'] ?? 'Trainer workout',
            },
          ),
        ),
      );
    }
  }

  Future<void> _startAssignment(
    BuildContext context,
    GymMembership membership,
    QueryDocumentSnapshot<Map<String, dynamic>> assignment,
  ) async {
    final repository = context.read<GymRepository>();
    final sharing = await repository.firestore
        .doc('users/${personalScope.uid}/gym_shares/${membership.gymId}')
        .get();
    final categories = Map<String, bool>.from(
      sharing.data()?['categories'] as Map? ?? const {},
    );
    var shareSummary = categories['workoutSummaries'] == true;
    if (!shareSummary && context.mounted) {
      final decision = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Share result with ${membership.gymName}?'),
          content: const Text(
            'The workout will always be saved to My Fitness. Sharing sends only a summary—not your full set-by-set personal record.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep private'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Share summaries'),
            ),
          ],
        ),
      );
      shareSummary = decision == true;
      if (shareSummary) {
        categories.addAll({
          'profile': categories['profile'] ?? false,
          'goals': categories['goals'] ?? false,
          'workoutSummaries': true,
          'measurements': categories['measurements'] ?? false,
          'progress': categories['progress'] ?? false,
        });
        await repository.updateGymSharing(
          gymId: membership.gymId,
          categories: categories,
        );
      }
    }
    if (!context.mounted) return;
    await openMemberWorkoutLogger(
      context,
      personalScope,
      origin: 'gymAssignment',
      sourceReference: {
        'gymId': membership.gymId,
        'assignmentId': assignment.id,
        'title': assignment.data()['title'] ?? 'Trainer workout',
        'sharedOnCompletion': shareSummary,
      },
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise, required this.onTap});

  final ExerciseGuide exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: ExerciseMediaImage(exercise: exercise, errorIconSize: 42),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('${exercise.primaryMuscle} · ${exercise.equipment}'),
                const SizedBox(height: 3),
                Text(
                  '${exercise.level} · ${exercise.movementPattern}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${exercise.defaultSets} sets · ${exercise.defaultReps}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ExerciseDetails extends StatelessWidget {
  const _ExerciseDetails({
    required this.exercise,
    required this.onVariationTap,
    required this.onAskSupport,
  });

  final ExerciseGuide exercise;
  final ValueChanged<ExerciseGuide> onVariationTap;
  final VoidCallback onAskSupport;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(exercise.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('${exercise.level} · ${exercise.equipment}'),
          const SizedBox(height: 16),
          SizedBox(
            height: 230,
            child: PageView(
              children: exercise.imageUrls.indexed
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer,
                              child: InteractiveViewer(
                                child: ExerciseMediaImage(
                                  exercise: exercise,
                                  imageIndex: item.$1,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              bottom: 12,
                              child: Chip(
                                avatar: Icon(
                                  item.$1 == 0
                                      ? Icons.first_page
                                      : Icons.last_page,
                                  size: 18,
                                ),
                                label: Text(
                                  item.$1 == 0
                                      ? 'Start position'
                                      : 'Finish position',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Target: ${exercise.primaryMuscle}')),
              Chip(label: Text(exercise.movementPattern)),
              Chip(label: Text('${exercise.defaultSets} sets')),
              Chip(label: Text(exercise.defaultReps)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'How to perform it',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...exercise.instructions.indexed.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 13, child: Text('${item.$1 + 1}')),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.$2)),
                ],
              ),
            ),
          ),
          if (exercise.coachingCues.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Coach cues', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...exercise.coachingCues.map(
              (cue) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(cue),
              ),
            ),
          ],
          if (exercise.commonMistakes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Common mistakes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...exercise.commonMistakes.map(
              (mistake) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(mistake),
              ),
            ),
          ],
          if (variationsFor(exercise).isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Try another variation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose a version that matches your equipment and experience.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: variationsFor(exercise)
                  .map(
                    (variation) => ActionChip(
                      avatar: const Icon(Icons.swap_horiz, size: 18),
                      label: Text(variation.name),
                      onPressed: () => onVariationTap(variation),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onAskSupport,
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Ask for help with this exercise'),
          ),
          const SizedBox(height: 10),
          const _TrainingSafetyNote(),
        ],
      ),
    ),
  );
}

class GuidedWorkoutScreen extends StatefulWidget {
  const GuidedWorkoutScreen({
    required this.scope,
    required this.goal,
    required this.exercises,
    this.initialDraft,
    super.key,
  });

  final FitnessScope scope;
  final TrainingGoal goal;
  final List<ExerciseGuide> exercises;
  final WorkoutDraft? initialDraft;

  @override
  State<GuidedWorkoutScreen> createState() => _GuidedWorkoutScreenState();
}

class _GuidedWorkoutScreenState extends State<GuidedWorkoutScreen> {
  late final DateTime _startedAt;
  late final List<int> _completedSets;
  late final List<TextEditingController> _weights;
  late final List<TextEditingController> _repsPerSet;
  int _exerciseIndex = 0;
  int _restRemaining = 0;
  Timer? _restTimer;
  Timer? _draftTimer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startedAt = widget.initialDraft?.startedAt ?? DateTime.now();
    _completedSets =
        widget.initialDraft?.completedSets.toList() ??
        List.filled(widget.exercises.length, 0);
    _weights = List.generate(
      widget.exercises.length,
      (index) => TextEditingController(
        text: widget.initialDraft?.weights[index] ?? '',
      ),
    );
    _repsPerSet = List.generate(
      widget.exercises.length,
      (index) => TextEditingController(
        text:
            widget.initialDraft?.repsPerSet[index] ??
            _suggestedReps(widget.exercises[index].defaultReps),
      ),
    );
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _draftTimer?.cancel();
    for (final controller in _weights) {
      controller.dispose();
    }
    for (final controller in _repsPerSet) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercises[_exerciseIndex];
    final completed = _completedSets[_exerciseIndex];
    final totalSets = widget.exercises.fold<int>(
      0,
      (total, item) => total + item.defaultSets,
    );
    final doneSets = _completedSets.fold<int>(0, (a, b) => a + b);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.goal.label),
        actions: [
          TextButton(
            onPressed: _saving || doneSets == 0 ? null : _finish,
            child: const Text('Finish'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LinearProgressIndicator(
            value: totalSets == 0 ? 0 : doneSets / totalSets,
          ),
          const SizedBox(height: 8),
          Text(
            'Exercise ${_exerciseIndex + 1} of ${widget.exercises.length} · $doneSets of $totalSets sets',
          ),
          const SizedBox(height: 18),
          Text(
            exercise.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text('${exercise.primaryMuscle} · ${exercise.equipment}'),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: PageView(
              children: exercise.imageUrls.indexed
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer,
                              child: ExerciseMediaImage(
                                exercise: exercise,
                                imageIndex: item.$1,
                                errorIconSize: 64,
                              ),
                            ),
                            Positioned(
                              left: 12,
                              bottom: 12,
                              child: Chip(
                                label: Text(item.$1 == 0 ? 'Start' : 'Finish'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to perform it',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...exercise.instructions.indexed.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${item.$1 + 1}. ${item.$2}'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Set performance',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _weights[_exerciseIndex],
                  onChanged: (_) => _scheduleDraftSave(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Working weight',
                    suffixText: 'kg',
                    helperText: 'Optional for bodyweight',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _repsPerSet[_exerciseIndex],
                  onChanged: (_) => _scheduleDraftSave(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Reps per set',
                    helperText: 'Target: ${exercise.defaultReps}',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'These values update your exercise history and records.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ...List.generate(
            exercise.defaultSets,
            (index) => Card(
              color: index < completed
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text('Set ${index + 1}'),
                subtitle: Text(exercise.defaultReps),
                trailing: Icon(
                  index < completed
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_restRemaining > 0)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('Rest $_restRemaining seconds'),
                trailing: TextButton(
                  onPressed: _stopRest,
                  child: const Text('Skip'),
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: completed >= exercise.defaultSets ? null : _completeSet,
            icon: const Icon(Icons.check),
            label: Text(
              completed >= exercise.defaultSets
                  ? 'All sets complete'
                  : 'Complete set ${completed + 1}',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _exerciseIndex == 0
                    ? null
                    : () => setState(() => _exerciseIndex--),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _exerciseIndex == widget.exercises.length - 1
                    ? null
                    : () => setState(() => _exerciseIndex++),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _TrainingSafetyNote(),
        ],
      ),
    );
  }

  void _completeSet() {
    final exercise = widget.exercises[_exerciseIndex];
    setState(() {
      _completedSets[_exerciseIndex]++;
      _restRemaining = exercise.restSeconds;
    });
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _restRemaining <= 1) {
        timer.cancel();
        if (mounted) setState(() => _restRemaining = 0);
      } else {
        setState(() => _restRemaining--);
      }
    });
    _scheduleDraftSave();
  }

  void _stopRest() {
    _restTimer?.cancel();
    setState(() => _restRemaining = 0);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final endedAt = DateTime.now();
      await context.read<GymRepository>().saveFitnessRecord(
        scope: widget.scope,
        collection: 'workout_logs',
        data: {
          'title': '${widget.goal.label} session',
          'goal': widget.goal.name,
          'status': 'completed',
          'startedAt': Timestamp.fromDate(_startedAt),
          'completedAt': Timestamp.fromDate(endedAt),
          'durationSeconds': endedAt.difference(_startedAt).inSeconds,
          'exercises': [
            for (var index = 0; index < widget.exercises.length; index++)
              {
                'exerciseId': widget.exercises[index].id,
                'name': widget.exercises[index].name,
                'completedSets': _completedSets[index],
                'targetSets': widget.exercises[index].defaultSets,
                'targetReps': widget.exercises[index].defaultReps,
                if (double.tryParse(_weights[index].text.trim())
                    case final weight?)
                  'weightKg': weight,
                if (int.tryParse(_repsPerSet[index].text.trim())
                    case final reps?)
                  'repsPerSet': reps,
              },
          ],
        },
      );
      await WorkoutDraftStore.clear(widget.scope.uid, widget.scope.draftKey);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.celebration_outlined, size: 42),
          title: const Text('Workout saved'),
          content: Text(
            'You completed ${_completedSets.fold<int>(0, (a, b) => a + b)} sets. Keep showing up!',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save workout: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 250), () {
      WorkoutDraftStore.save(
        WorkoutDraft(
          gymId: widget.scope.draftKey,
          uid: widget.scope.uid,
          goal: widget.goal.name,
          exerciseIds: widget.exercises
              .map((exercise) => exercise.id)
              .toList(growable: false),
          completedSets: _completedSets.toList(growable: false),
          weights: _weights
              .map((controller) => controller.text)
              .toList(growable: false),
          repsPerSet: _repsPerSet
              .map((controller) => controller.text)
              .toList(growable: false),
          startedAt: _startedAt,
        ),
      );
    });
  }

  static String _suggestedReps(String target) =>
      RegExp(r'\d+').firstMatch(target)?.group(0) ?? '';
}

class _TrainingSafetyNote extends StatelessWidget {
  const _TrainingSafetyNote();

  @override
  Widget build(BuildContext context) => Card(
    child: const ListTile(
      leading: Icon(Icons.health_and_safety_outlined),
      title: Text('Train safely'),
      subtitle: Text(
        'Use a manageable load and controlled form. Stop if you feel sharp pain, dizziness, or unusual discomfort, and ask your trainer or a qualified healthcare professional when needed.',
      ),
    ),
  );
}
