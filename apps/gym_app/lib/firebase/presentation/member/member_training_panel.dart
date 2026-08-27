import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_core/gym_core.dart';

import '../../data/gym_repository.dart';
import '../../domain/exercise_guide.dart';

class MemberTrainingPanel extends StatefulWidget {
  const MemberTrainingPanel({required this.membership, super.key});

  final GymMembership membership;

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
    final query = _search.text.trim().toLowerCase();
    final filtered = exerciseGuides
        .where((exercise) {
          final matchesGoal = exercise.goals.contains(_goal);
          final matchesQuery =
              query.isEmpty ||
              exercise.name.toLowerCase().contains(query) ||
              exercise.primaryMuscle.toLowerCase().contains(query) ||
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
        _TrainerAssignments(membership: widget.membership),
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

  Future<void> _startWorkout(BuildContext context) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GuidedWorkoutScreen(
            membership: widget.membership,
            goal: _goal,
            exercises: exercisesForGoal(_goal, limit: 5),
          ),
        ),
      );

  Future<void> _showExercise(BuildContext context, ExerciseGuide exercise) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _ExerciseDetails(exercise: exercise),
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
            child: CachedNetworkImage(
              imageUrl: exercise.imageUrls.first,
              fit: BoxFit.contain,
              placeholder: (_, _) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (_, _, _) => const ColoredBox(
                color: Color(0x11000000),
                child: Center(child: Icon(Icons.fitness_center, size: 42)),
              ),
            ),
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
  const _ExerciseDetails({required this.exercise});

  final ExerciseGuide exercise;

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
              children: exercise.imageUrls
                  .map(
                    (url) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.contain,
                            errorWidget: (_, _, _) =>
                                const Icon(Icons.fitness_center, size: 52),
                          ),
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
          const SizedBox(height: 10),
          const _TrainingSafetyNote(),
        ],
      ),
    ),
  );
}

class GuidedWorkoutScreen extends StatefulWidget {
  const GuidedWorkoutScreen({
    required this.membership,
    required this.goal,
    required this.exercises,
    super.key,
  });

  final GymMembership membership;
  final TrainingGoal goal;
  final List<ExerciseGuide> exercises;

  @override
  State<GuidedWorkoutScreen> createState() => _GuidedWorkoutScreenState();
}

class _GuidedWorkoutScreenState extends State<GuidedWorkoutScreen> {
  late final DateTime _startedAt;
  late final List<int> _completedSets;
  late final List<TextEditingController> _weights;
  int _exerciseIndex = 0;
  int _restRemaining = 0;
  Timer? _restTimer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _completedSets = List.filled(widget.exercises.length, 0);
    _weights = List.generate(
      widget.exercises.length,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    for (final controller in _weights) {
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
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: CachedNetworkImage(
                  imageUrl: exercise.imageUrls[completed.isEven ? 0 : 1],
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) =>
                      const Icon(Icons.fitness_center, size: 64),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(exercise.instructions.first),
          const SizedBox(height: 20),
          Text(
            'Working weight',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _weights[_exerciseIndex],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Weight in kg (optional)',
              suffixText: 'kg',
              border: OutlineInputBorder(),
            ),
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
  }

  void _stopRest() {
    _restTimer?.cancel();
    setState(() => _restRemaining = 0);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final endedAt = DateTime.now();
      await context.read<GymRepository>().saveMemberOwnedRecord(
        gymId: widget.membership.gymId,
        collection: 'workout_logs',
        uid: widget.membership.uid,
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
              },
          ],
        },
      );
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
