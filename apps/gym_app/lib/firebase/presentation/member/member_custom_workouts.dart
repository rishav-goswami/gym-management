import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_core/gym_core.dart';

import '../../data/gym_repository.dart';
import '../../domain/custom_workout.dart';
import '../../domain/exercise_guide.dart';

class MemberRoutinesSection extends StatelessWidget {
  const MemberRoutinesSection({required this.membership, super.key});

  final GymMembership membership;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: context.read<GymRepository>().memberRoutines(
      membership.gymId,
      membership.uid,
      limit: 30,
    ),
    builder: (context, snapshot) {
      final routines =
          snapshot.data?.docs
              .map(
                (document) =>
                    MemberRoutine.fromMap(document.id, document.data()),
              )
              .where((routine) => routine.status == 'active')
              .toList(growable: false) ??
          const <MemberRoutine>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My routines',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'Build a repeatable day or log anything you did today.',
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Add workout',
                icon: const Icon(Icons.add_circle_outline),
                onSelected: (value) {
                  if (value == 'routine') {
                    _openRoutineBuilder(context, membership);
                  } else {
                    _openWorkoutLogger(context, membership);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'log', child: Text('Quick log workout')),
                  PopupMenuItem(
                    value: 'routine',
                    child: Text('Create routine'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => _openWorkoutLogger(context, membership),
            icon: const Icon(Icons.edit_note),
            label: const Text('Log today’s workout'),
          ),
          if (snapshot.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Unable to load routines: ${snapshot.error}'),
            )
          else if (!snapshot.hasData)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            )
          else if (routines.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.calendar_view_week_outlined),
                title: Text('Create your first weekly routine'),
                subtitle: Text(
                  'Add strength, bodyweight, cardio, or timed movements and schedule the days you prefer.',
                ),
              ),
            )
          else
            ...routines.map(
              (routine) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(child: Icon(Icons.event_repeat)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  routine.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  '${routine.movements.length} movements · ${_weekdaySummary(routine.scheduledWeekdays)}',
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openRoutineBuilder(
                                  context,
                                  membership,
                                  routine: routine,
                                );
                              } else {
                                _deleteRoutine(context, membership, routine);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: routine.movements
                            .take(6)
                            .map(
                              (movement) => Chip(
                                label: Text(
                                  '${movement.name} · ${movement.targetSets} ${movement.targetSets == 1 ? 'effort' : 'sets'}',
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => _openWorkoutLogger(
                          context,
                          membership,
                          routine: routine,
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start and log'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

Future<void> _openRoutineBuilder(
  BuildContext context,
  GymMembership membership, {
  MemberRoutine? routine,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        RoutineBuilderScreen(membership: membership, routine: routine),
  ),
);

Future<void> _openWorkoutLogger(
  BuildContext context,
  GymMembership membership, {
  MemberRoutine? routine,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        MemberWorkoutLoggerScreen(membership: membership, routine: routine),
  ),
);

Future<void> _deleteRoutine(
  BuildContext context,
  GymMembership membership,
  MemberRoutine routine,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete routine?'),
      content: Text(
        '${routine.name} will be removed. Completed workout history is kept.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await context.read<GymRepository>().deleteMemberRoutine(
    gymId: membership.gymId,
    routineId: routine.id,
  );
}

class RoutineBuilderScreen extends StatefulWidget {
  const RoutineBuilderScreen({
    required this.membership,
    this.routine,
    super.key,
  });

  final GymMembership membership;
  final MemberRoutine? routine;

  @override
  State<RoutineBuilderScreen> createState() => _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends State<RoutineBuilderScreen> {
  late final TextEditingController _name;
  late final Set<int> _weekdays;
  late final List<RoutineMovement> _movements;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.routine?.name ?? '');
    _weekdays = {...?widget.routine?.scheduledWeekdays};
    _movements = [...?widget.routine?.movements];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.routine == null ? 'Create routine' : 'Edit routine'),
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _name,
          autofocus: widget.routine == null,
          decoration: const InputDecoration(
            labelText: 'Routine name',
            hintText: 'Push day, Monday strength, Cardio day…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Text('Repeat on', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: List.generate(7, (index) {
            final day = index + 1;
            return FilterChip(
              label: Text(_weekdayLabels[index]),
              selected: _weekdays.contains(day),
              onSelected: (selected) => setState(() {
                selected ? _weekdays.add(day) : _weekdays.remove(day);
              }),
            );
          }),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Movements',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _addMovement,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_movements.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Add catalog exercises or a custom movement such as treadmill running, skipping, or a sport drill.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ..._movements.indexed.map((item) {
            final movement = item.$2;
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${item.$1 + 1}')),
                title: Text(movement.name),
                subtitle: Text(
                  '${movement.trackingType.label} · ${movement.targetSets} ${movement.targetSets == 1 ? 'effort' : 'sets'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Fewer sets',
                      onPressed: movement.targetSets <= 1
                          ? null
                          : () => _changeSets(item.$1, -1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'More sets',
                      onPressed: () => _changeSets(item.$1, 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'Remove movement',
                      onPressed: () =>
                          setState(() => _movements.removeAt(item.$1)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            widget.routine == null ? 'Create routine' : 'Save changes',
          ),
        ),
      ],
    ),
  );

  Future<void> _addMovement() async {
    final movement = await showMovementPicker(context);
    if (movement != null) setState(() => _movements.add(movement));
  }

  void _changeSets(int index, int delta) {
    final current = _movements[index];
    setState(() {
      _movements[index] = RoutineMovement(
        id: current.id,
        exerciseId: current.exerciseId,
        name: current.name,
        trackingType: current.trackingType,
        targetSets: (current.targetSets + delta).clamp(1, 20),
        notes: current.notes,
      );
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      _message('Give the routine a name.');
      return;
    }
    if (_movements.isEmpty) {
      _message('Add at least one movement.');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<GymRepository>().saveMemberRoutine(
        gymId: widget.membership.gymId,
        uid: widget.membership.uid,
        routineId: widget.routine?.id,
        name: _name.text,
        scheduledWeekdays: _weekdays.toList()..sort(),
        movements: _movements
            .map((item) => item.toMap())
            .toList(growable: false),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      _message('Unable to save routine: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
}

class MemberWorkoutLoggerScreen extends StatefulWidget {
  const MemberWorkoutLoggerScreen({
    required this.membership,
    this.routine,
    super.key,
  });

  final GymMembership membership;
  final MemberRoutine? routine;

  @override
  State<MemberWorkoutLoggerScreen> createState() =>
      _MemberWorkoutLoggerScreenState();
}

class _MemberWorkoutLoggerScreenState extends State<MemberWorkoutLoggerScreen> {
  late final DateTime _startedAt;
  late final TextEditingController _title;
  late final List<_MovementInput> _movements;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _title = TextEditingController(
      text: widget.routine?.name ?? 'Today’s workout',
    );
    _movements =
        widget.routine?.movements.map(_MovementInput.fromRoutine).toList() ??
        [];
  }

  @override
  void dispose() {
    _title.dispose();
    for (final movement in _movements) {
      movement.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Log workout'),
      actions: [
        TextButton(
          onPressed: _saving ? null : _finish,
          child: const Text('Finish'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'Workout title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.auto_graph),
            title: Text('Every completed set updates Progress'),
            subtitle: Text(
              'Log the values you actually completed. Different weights and reps can be entered for every set.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        ..._movements.indexed.map(
          (item) => _MovementLogCard(
            key: ValueKey(item.$2.id),
            movement: item.$2,
            number: item.$1 + 1,
            onRemove: () {
              setState(() {
                final removed = _movements.removeAt(item.$1);
                removed.dispose();
              });
            },
            onChanged: () => setState(() {}),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _addMovement,
          icon: const Icon(Icons.add),
          label: const Text('Add movement'),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving ? null : _finish,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Finish and save workout'),
        ),
      ],
    ),
  );

  Future<void> _addMovement() async {
    final movement = await showMovementPicker(context);
    if (movement != null) {
      setState(() => _movements.add(_MovementInput.fromRoutine(movement)));
    }
  }

  Future<void> _finish() async {
    final logged = _movements
        .map((movement) => movement.toLogMap())
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    if (logged.isEmpty) {
      _message('Log at least one completed set or cardio effort.');
      return;
    }
    setState(() => _saving = true);
    try {
      final endedAt = DateTime.now();
      await context.read<GymRepository>().saveMemberOwnedRecord(
        gymId: widget.membership.gymId,
        collection: 'workout_logs',
        uid: widget.membership.uid,
        data: {
          'schemaVersion': 2,
          'title': _title.text.trim().isEmpty ? 'Workout' : _title.text.trim(),
          'source': widget.routine == null ? 'quick_log' : 'member_routine',
          if (widget.routine != null) 'routineId': widget.routine!.id,
          'status': 'completed',
          'startedAt': Timestamp.fromDate(_startedAt),
          'completedAt': Timestamp.fromDate(endedAt),
          'durationSeconds': endedAt.difference(_startedAt).inSeconds,
          'exercises': logged,
        },
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.celebration_outlined),
          title: const Text('Workout logged'),
          content: Text(
            '${logged.length} movements were saved and connected to Progress.',
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
      _message('Unable to save workout: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
}

class _MovementLogCard extends StatelessWidget {
  const _MovementLogCard({
    required this.movement,
    required this.number,
    required this.onRemove,
    required this.onChanged,
    super.key,
  });

  final _MovementInput movement;
  final int number;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(child: Text('$number')),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movement.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(movement.trackingType.label),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove movement',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (movement.trackingType == MovementTrackingType.cardio)
            for (final item in movement.sets.indexed)
              _CardioSetRow(
                set: item.$2,
                number: item.$1 + 1,
                canRemove: movement.sets.length > 1,
                onRemove: () {
                  movement.removeSet(item.$1);
                  onChanged();
                },
              )
          else if (movement.trackingType == MovementTrackingType.timed)
            for (final item in movement.sets.indexed)
              _TimedSetRow(
                set: item.$2,
                number: item.$1 + 1,
                canRemove: movement.sets.length > 1,
                onRemove: () {
                  movement.removeSet(item.$1);
                  onChanged();
                },
              )
          else
            for (final item in movement.sets.indexed)
              _RepSetRow(
                set: item.$2,
                number: item.$1 + 1,
                bodyweight:
                    movement.trackingType == MovementTrackingType.bodyweight,
                canRemove: movement.sets.length > 1,
                onRemove: () {
                  movement.removeSet(item.$1);
                  onChanged();
                },
              ),
          TextButton.icon(
            onPressed: () {
              movement.addSet();
              onChanged();
            },
            icon: const Icon(Icons.add),
            label: Text(
              movement.trackingType == MovementTrackingType.cardio
                  ? 'Add cardio interval'
                  : 'Add set',
            ),
          ),
          TextField(
            controller: movement.notes,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Movement notes (optional)',
              hintText: 'Weight belt, machine setting, form note…',
            ),
          ),
        ],
      ),
    ),
  );
}

class _RepSetRow extends StatelessWidget {
  const _RepSetRow({
    required this.set,
    required this.number,
    required this.bodyweight,
    required this.canRemove,
    required this.onRemove,
  });

  final _SetInput set;
  final int number;
  final bool bodyweight;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('$number'),
          ),
        ),
        Expanded(
          child: _NumberField(
            controller: set.reps,
            label: 'Reps',
            decimal: false,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NumberField(
            controller: bodyweight ? set.additionalLoadKg : set.weightKg,
            label: bodyweight ? 'Added load' : 'Weight',
            suffix: 'kg',
          ),
        ),
        IconButton(
          onPressed: canRemove ? onRemove : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    ),
  );
}

class _CardioSetRow extends StatelessWidget {
  const _CardioSetRow({
    required this.set,
    required this.number,
    required this.canRemove,
    required this.onRemove,
  });

  final _SetInput set;
  final int number;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Interval $number')),
              IconButton(
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SizedNumberField(
                controller: set.durationMinutes,
                label: 'Minutes',
              ),
              _SizedNumberField(
                controller: set.speedKph,
                label: 'Speed',
                suffix: 'km/h',
              ),
              _SizedNumberField(
                controller: set.inclinePercent,
                label: 'Incline',
                suffix: '%',
              ),
              _SizedNumberField(
                controller: set.distanceKm,
                label: 'Distance',
                suffix: 'km',
              ),
              _SizedNumberField(
                controller: set.additionalLoadKg,
                label: 'Added load',
                suffix: 'kg',
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TimedSetRow extends StatelessWidget {
  const _TimedSetRow({
    required this.set,
    required this.number,
    required this.canRemove,
    required this.onRemove,
  });

  final _SetInput set;
  final int number;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(width: 28, child: Text('$number')),
        Expanded(
          child: _NumberField(
            controller: set.durationSeconds,
            label: 'Duration',
            suffix: 'sec',
            decimal: false,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NumberField(
            controller: set.additionalLoadKg,
            label: 'Added load',
            suffix: 'kg',
          ),
        ),
        IconButton(
          onPressed: canRemove ? onRemove : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    ),
  );
}

class _SizedNumberField extends StatelessWidget {
  const _SizedNumberField({
    required this.controller,
    required this.label,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 145,
    child: _NumberField(controller: controller, label: label, suffix: suffix),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.suffix,
    this.decimal = true,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final bool decimal;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      isDense: true,
      border: const OutlineInputBorder(),
    ),
  );
}

class _MovementInput {
  _MovementInput({
    required this.id,
    required this.exerciseId,
    required this.name,
    required this.trackingType,
    required int targetSets,
  }) : sets = List.generate(targetSets, (_) => _SetInput()),
       notes = TextEditingController();

  factory _MovementInput.fromRoutine(RoutineMovement movement) =>
      _MovementInput(
        id: movement.id,
        exerciseId: movement.exerciseId,
        name: movement.name,
        trackingType: movement.trackingType,
        targetSets: movement.targetSets,
      );

  final String id;
  final String? exerciseId;
  final String name;
  final MovementTrackingType trackingType;
  final List<_SetInput> sets;
  final TextEditingController notes;

  void addSet() => sets.add(_SetInput());

  void removeSet(int index) => sets.removeAt(index).dispose();

  Map<String, dynamic>? toLogMap() {
    final loggedSets = sets
        .map((set) => set.value)
        .where((set) => set.hasData)
        .toList(growable: false);
    if (loggedSets.isEmpty) return null;
    final reps = loggedSets
        .map((set) => set.reps ?? 0)
        .where((value) => value > 0);
    final weights = loggedSets.map((set) => set.weightKg).whereType<double>();
    return {
      'exerciseId': exerciseId ?? id,
      'movementId': id,
      'name': name,
      'trackingType': trackingType.name,
      'completedSets': loggedSets.length,
      'sets': [
        for (final item in loggedSets.indexed) item.$2.toMap(item.$1 + 1),
      ],
      if (reps.isNotEmpty) 'repsPerSet': reps.first,
      if (weights.isNotEmpty)
        'weightKg': weights.reduce((a, b) => a > b ? a : b),
      if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
    };
  }

  void dispose() {
    notes.dispose();
    for (final set in sets) {
      set.dispose();
    }
  }
}

class _SetInput {
  final reps = TextEditingController();
  final weightKg = TextEditingController();
  final additionalLoadKg = TextEditingController();
  final durationSeconds = TextEditingController();
  final durationMinutes = TextEditingController();
  final speedKph = TextEditingController();
  final inclinePercent = TextEditingController();
  final distanceKm = TextEditingController();

  LoggedMovementSet get value {
    final minutes = _positiveDouble(durationMinutes.text);
    return LoggedMovementSet(
      reps: _positiveInt(reps.text),
      weightKg: _nonNegativeDouble(weightKg.text),
      additionalLoadKg: _nonNegativeDouble(additionalLoadKg.text),
      durationSeconds:
          _positiveInt(durationSeconds.text) ??
          (minutes == null ? null : (minutes * 60).round()),
      speedKph: _positiveDouble(speedKph.text),
      inclinePercent: _nonNegativeDouble(inclinePercent.text),
      distanceKm: _positiveDouble(distanceKm.text),
    );
  }

  void dispose() {
    reps.dispose();
    weightKg.dispose();
    additionalLoadKg.dispose();
    durationSeconds.dispose();
    durationMinutes.dispose();
    speedKph.dispose();
    inclinePercent.dispose();
    distanceKm.dispose();
  }
}

Future<RoutineMovement?> showMovementPicker(BuildContext context) async {
  ExerciseGuide? selectedExercise;
  final customName = TextEditingController();
  var custom = false;
  var type = MovementTrackingType.strength;
  var sets = 3;
  final result = await showDialog<RoutineMovement>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add movement'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Exercise library'),
                    ),
                    ButtonSegment(value: true, label: Text('Custom movement')),
                  ],
                  selected: {custom},
                  onSelectionChanged: (value) => setDialogState(() {
                    custom = value.first;
                    if (custom) selectedExercise = null;
                  }),
                ),
                const SizedBox(height: 16),
                if (custom)
                  TextField(
                    controller: customName,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Movement name',
                      hintText: 'Treadmill run, muscle-up, football…',
                      border: OutlineInputBorder(),
                    ),
                  )
                else
                  DropdownButtonFormField<ExerciseGuide>(
                    initialValue: selectedExercise,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Exercise',
                      border: OutlineInputBorder(),
                    ),
                    items: exerciseGuides
                        .map(
                          (exercise) => DropdownMenuItem(
                            value: exercise,
                            child: Text(exercise.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setDialogState(() {
                      selectedExercise = value;
                      if (value != null) {
                        type = value.equipment.toLowerCase() == 'bodyweight'
                            ? MovementTrackingType.bodyweight
                            : MovementTrackingType.strength;
                        sets = value.defaultSets;
                      }
                    }),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MovementTrackingType>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'How do you track it?',
                    border: OutlineInputBorder(),
                  ),
                  items: MovementTrackingType.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text('${item.label} · ${item.description}'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => type = value);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Text('Starting sets / intervals')),
                    IconButton(
                      onPressed: sets <= 1
                          ? null
                          : () => setDialogState(() => sets--),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$sets'),
                    IconButton(
                      onPressed: sets >= 20
                          ? null
                          : () => setDialogState(() => sets++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = custom
                  ? customName.text.trim()
                  : selectedExercise?.name;
              if (name == null || name.length < 2) return;
              final now = DateTime.now().microsecondsSinceEpoch;
              Navigator.pop(
                dialogContext,
                RoutineMovement(
                  id: '${selectedExercise?.id ?? _slug(name)}-$now',
                  exerciseId: selectedExercise?.id,
                  name: name,
                  trackingType: type,
                  targetSets: sets,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
  customName.dispose();
  return result;
}

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _weekdaySummary(List<int> days) => days.isEmpty
    ? 'Any day'
    : days.map((day) => _weekdayLabels[day - 1]).join(', ');

String _slug(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

int? _positiveInt(String value) {
  final parsed = int.tryParse(value.trim());
  return parsed != null && parsed > 0 ? parsed : null;
}

double? _positiveDouble(String value) {
  final parsed = double.tryParse(value.trim());
  return parsed != null && parsed > 0 ? parsed : null;
}

double? _nonNegativeDouble(String value) {
  final parsed = double.tryParse(value.trim());
  return parsed != null && parsed >= 0 ? parsed : null;
}
