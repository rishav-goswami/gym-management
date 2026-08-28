import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_core/gym_core.dart';
import 'package:intl/intl.dart';

import '../../data/gym_media_repository.dart';
import '../../data/gym_repository.dart';
import '../../domain/exercise_guide.dart';
import '../../domain/member_progress.dart';
import 'exercise_media_image.dart';

enum _ProgressSection { overview, exercises, body }

enum _ExerciseMetric {
  weight,
  estimatedMax,
  volume,
  reps,
  duration,
  speed,
  distance,
}

class MemberProgressPanel extends StatefulWidget {
  const MemberProgressPanel({required this.scope, super.key});

  final FitnessScope scope;

  @override
  State<MemberProgressPanel> createState() => _MemberProgressPanelState();
}

class _MemberProgressPanelState extends State<MemberProgressPanel> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _workouts;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _measurements;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _photos;
  _ProgressSection _section = _ProgressSection.overview;
  String? _selectedExerciseId;

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  @override
  void didUpdateWidget(covariant MemberProgressPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      _selectedExerciseId = null;
      _bindStreams();
    }
  }

  void _bindStreams() {
    final repository = context.read<GymRepository>();
    _workouts = repository.fitnessRecords(
      widget.scope,
      'workout_logs',
      limit: 100,
    );
    _measurements = repository.fitnessRecords(
      widget.scope,
      'measurements',
      limit: 100,
    );
    _photos = repository.fitnessProgressPhotos(widget.scope, limit: 24);
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _workouts,
        builder: (context, workoutSnapshot) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _measurements,
              builder: (context, measurementSnapshot) =>
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _photos,
                    builder: (context, photoSnapshot) {
                      final error =
                          workoutSnapshot.error ??
                          measurementSnapshot.error ??
                          photoSnapshot.error;
                      if (error != null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('Unable to load progress: $error'),
                          ),
                        );
                      }
                      if (!workoutSnapshot.hasData ||
                          !measurementSnapshot.hasData ||
                          !photoSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final progress = MemberWorkoutProgress.fromLogs(
                        workoutSnapshot.data!.docs.map(
                          (document) => (
                            id: document.id,
                            data: _withDate(document.data(), 'completedAt'),
                          ),
                        ),
                      );
                      final measurements =
                          measurementSnapshot.data!.docs
                              .map(_bodyMeasurement)
                              .whereType<_BodyMeasurement>()
                              .toList()
                            ..sort(
                              (left, right) =>
                                  left.measuredAt.compareTo(right.measuredAt),
                            );
                      final photoDocuments = [...photoSnapshot.data!.docs]
                        ..sort((left, right) {
                          final leftTime =
                              (left.data()['createdAt'] as Timestamp?)
                                  ?.millisecondsSinceEpoch ??
                              0;
                          final rightTime =
                              (right.data()['createdAt'] as Timestamp?)
                                  ?.millisecondsSinceEpoch ??
                              0;
                          return rightTime.compareTo(leftTime);
                        });
                      final photoPaths = photoDocuments
                          .map(
                            (document) =>
                                document.data()['storagePath'] as String?,
                          )
                          .whereType<String>()
                          .toList(growable: false);

                      return ListView(
                        padding: EdgeInsets.fromLTRB(
                          MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                          20,
                          MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                          40,
                        ),
                        children: [
                          _ProgressHeader(
                            section: _section,
                            onSectionChanged: (value) =>
                                setState(() => _section = value),
                            onMeasurement: _showMeasurement,
                            onPhoto: _uploadProgressPhoto,
                            photosEnabled: widget.scope.feature(
                              'progressPhotos',
                            ),
                          ),
                          const SizedBox(height: 22),
                          switch (_section) {
                            _ProgressSection.overview => _OverviewSection(
                              progress: progress,
                              measurements: measurements,
                            ),
                            _ProgressSection.exercises => _ExercisesSection(
                              progress: progress,
                              selectedExerciseId: _selectedExerciseId,
                              onExerciseChanged: (value) =>
                                  setState(() => _selectedExerciseId = value),
                            ),
                            _ProgressSection.body => _BodySection(
                              measurements: measurements,
                              photoPaths: photoPaths,
                            ),
                          },
                        ],
                      );
                    },
                  ),
            ),
      );

  Map<String, dynamic> _withDate(Map<String, dynamic> data, String field) {
    final value = data[field];
    return {...data, if (value is Timestamp) field: value.toDate()};
  }

  _BodyMeasurement? _bodyMeasurement(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final value = data['measuredAt'] ?? data['createdAt'];
    final measuredAt = value is Timestamp ? value.toDate() : null;
    final weight = (data['weightKg'] as num?)?.toDouble();
    if (measuredAt == null || weight == null) return null;
    return _BodyMeasurement(
      id: document.id,
      measuredAt: measuredAt,
      weightKg: weight,
      bodyFatPercent: (data['bodyFatPercent'] as num?)?.toDouble(),
    );
  }

  Future<void> _showMeasurement() async {
    final weight = TextEditingController();
    final bodyFat = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log body measurement'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: weight,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  suffixText: 'kg',
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  return parsed == null || parsed <= 20 || parsed > 500
                      ? 'Enter a weight between 20 and 500 kg'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: bodyFat,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Body fat (optional)',
                  suffixText: '%',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final parsed = double.tryParse(value.trim());
                  return parsed == null || parsed < 2 || parsed > 70
                      ? 'Enter a percentage between 2 and 70'
                      : null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await context.read<GymRepository>().saveFitnessRecord(
        scope: widget.scope,
        collection: 'measurements',
        data: {
          'weightKg': double.parse(weight.text.trim()),
          if (bodyFat.text.trim().isNotEmpty)
            'bodyFatPercent': double.parse(bodyFat.text.trim()),
          'measuredAt': Timestamp.now(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Measurement saved.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to save: $error')));
      }
    } finally {
      weight.dispose();
      bodyFat.dispose();
    }
  }

  Future<void> _uploadProgressPhoto() async {
    try {
      final path = await context
          .read<GymMediaRepository>()
          .pickAndUploadFitnessProgressPhoto(scope: widget.scope);
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Private progress photo uploaded.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to upload photo: $error')),
        );
      }
    }
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.section,
    required this.onSectionChanged,
    required this.onMeasurement,
    required this.onPhoto,
    required this.photosEnabled,
  });

  final _ProgressSection section;
  final ValueChanged<_ProgressSection> onSectionChanged;
  final VoidCallback onMeasurement;
  final VoidCallback onPhoto;
  final bool photosEnabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Progress',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text(
                'Workouts, exercise performance, and body changes together.',
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              if (photosEnabled)
                OutlinedButton.icon(
                  onPressed: onPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add photo'),
                ),
              FilledButton.icon(
                onPressed: onMeasurement,
                icon: const Icon(Icons.monitor_weight_outlined),
                label: const Text('Log body'),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 18),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<_ProgressSection>(
          segments: const [
            ButtonSegment(
              value: _ProgressSection.overview,
              icon: Icon(Icons.dashboard_outlined),
              label: Text('Overview'),
            ),
            ButtonSegment(
              value: _ProgressSection.exercises,
              icon: Icon(Icons.fitness_center),
              label: Text('Exercises'),
            ),
            ButtonSegment(
              value: _ProgressSection.body,
              icon: Icon(Icons.monitor_weight_outlined),
              label: Text('Body'),
            ),
          ],
          selected: {section},
          onSelectionChanged: (values) => onSectionChanged(values.first),
        ),
      ),
    ],
  );
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.progress, required this.measurements});

  final MemberWorkoutProgress progress;
  final List<_BodyMeasurement> measurements;

  @override
  Widget build(BuildContext context) {
    final recent = progress.since(
      DateTime.now().subtract(const Duration(days: 28)),
    );
    final sets = recent.fold(
      0,
      (total, session) => total + session.completedSets,
    );
    final minutes = recent.fold(
      0,
      (total, session) => total + (session.durationSeconds / 60).round(),
    );
    final volume = recent.fold(
      0.0,
      (total, session) => total + session.volumeKg,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricGrid(
          metrics: [
            _Metric('Workouts', '${recent.length}', Icons.event_available),
            _Metric('Completed sets', '$sets', Icons.repeat),
            _Metric('Training time', '$minutes min', Icons.timer_outlined),
            _Metric('Volume', _compactWeight(volume), Icons.trending_up),
          ],
        ),
        const SizedBox(height: 20),
        _SectionCard(
          title: '8-week consistency',
          subtitle: 'Completed workouts per week',
          child: SizedBox(
            height: 190,
            child: _WeeklyWorkoutChart(progress: progress),
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(
          title: 'Recent workouts',
          trailing: '${progress.sessions.length} logged',
        ),
        const SizedBox(height: 8),
        if (progress.sessions.isEmpty)
          const _EmptyProgress(
            icon: Icons.fitness_center,
            title: 'Complete your first workout',
            message:
                'Your exercise history and records will appear here automatically.',
          )
        else
          ...progress.sessions.reversed
              .take(8)
              .map(
                (session) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.check)),
                    title: Text(session.title),
                    subtitle: Text(
                      '${DateFormat('dd MMM, h:mm a').format(session.completedAt)} · '
                      '${session.completedSets} sets · '
                      '${(session.durationSeconds / 60).round()} min',
                    ),
                    trailing: session.volumeKg > 0
                        ? Text(_compactWeight(session.volumeKg))
                        : null,
                  ),
                ),
              ),
        if (measurements.isNotEmpty) ...[
          const SizedBox(height: 16),
          _BodySnapshot(measurements: measurements),
        ],
      ],
    );
  }
}

class _ExercisesSection extends StatefulWidget {
  const _ExercisesSection({
    required this.progress,
    required this.selectedExerciseId,
    required this.onExerciseChanged,
  });

  final MemberWorkoutProgress progress;
  final String? selectedExerciseId;
  final ValueChanged<String> onExerciseChanged;

  @override
  State<_ExercisesSection> createState() => _ExercisesSectionState();
}

class _ExercisesSectionState extends State<_ExercisesSection> {
  _ExerciseMetric _metric = _ExerciseMetric.weight;

  @override
  Widget build(BuildContext context) {
    if (widget.progress.exercises.isEmpty) {
      return const _EmptyProgress(
        icon: Icons.insights,
        title: 'No exercise history yet',
        message:
            'Finish a guided workout to unlock exercise charts and records.',
      );
    }
    final selectedId =
        widget.progress.exercises.any(
          (exercise) => exercise.exerciseId == widget.selectedExerciseId,
        )
        ? widget.selectedExerciseId!
        : widget.progress.exercises.first.exerciseId;
    final exercise = widget.progress.exercises.firstWhere(
      (item) => item.exerciseId == selectedId,
    );
    final guide = exerciseGuides
        .where((item) => item.id == exercise.exerciseId)
        .firstOrNull;
    final availableMetrics = exercise.isCardio
        ? const [
            _ExerciseMetric.duration,
            _ExerciseMetric.speed,
            _ExerciseMetric.distance,
          ]
        : exercise.isTimed
        ? const [_ExerciseMetric.duration]
        : exercise.hasWeight
        ? const [
            _ExerciseMetric.weight,
            _ExerciseMetric.estimatedMax,
            _ExerciseMetric.volume,
          ]
        : const [_ExerciseMetric.reps];
    if (!availableMetrics.contains(_metric)) _metric = availableMetrics.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(selectedId),
          initialValue: selectedId,
          decoration: const InputDecoration(
            labelText: 'Exercise history',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          items: widget.progress.exercises
              .map(
                (item) => DropdownMenuItem(
                  value: item.exerciseId,
                  child: Text(item.exerciseName),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) widget.onExerciseChanged(value);
          },
        ),
        const SizedBox(height: 16),
        if (guide != null)
          Card(
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 130,
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: ExerciseMediaImage(
                      exercise: guide,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            guide.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text('${guide.primaryMuscle} · ${guide.equipment}'),
                          Text('${exercise.entries.length} completed sessions'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        _MetricGrid(
          metrics: exercise.isCardio
              ? [
                  _Metric(
                    'Longest time',
                    _duration(exercise.bestDurationSeconds),
                    Icons.timer_outlined,
                  ),
                  _Metric(
                    'Best speed',
                    '${_number(exercise.bestSpeedKph)} km/h',
                    Icons.speed,
                  ),
                  _Metric(
                    'Longest distance',
                    '${_number(exercise.longestDistanceKm)} km',
                    Icons.route_outlined,
                  ),
                  _Metric(
                    'Highest incline',
                    '${_number(exercise.bestInclinePercent)}%',
                    Icons.trending_up,
                  ),
                ]
              : exercise.isTimed
              ? [
                  _Metric(
                    'Best duration',
                    _duration(exercise.bestDurationSeconds),
                    Icons.timer_outlined,
                  ),
                  _Metric(
                    'Sessions',
                    '${exercise.entries.length}',
                    Icons.event_available,
                  ),
                ]
              : exercise.hasWeight
              ? [
                  _Metric(
                    'Best weight',
                    '${_number(exercise.bestWeightKg)} kg',
                    Icons.fitness_center,
                  ),
                  _Metric(
                    'Estimated 1RM',
                    '${_number(exercise.bestEstimatedOneRepMaxKg)} kg',
                    Icons.emoji_events_outlined,
                  ),
                  _Metric(
                    'Best session volume',
                    _compactWeight(exercise.bestSessionVolumeKg),
                    Icons.trending_up,
                  ),
                ]
              : [
                  _Metric(
                    'Best set',
                    '${exercise.bestSetReps} reps',
                    Icons.repeat,
                  ),
                  _Metric(
                    'Best session',
                    '${exercise.bestSessionReps} reps',
                    Icons.emoji_events_outlined,
                  ),
                  _Metric(
                    'Sessions',
                    '${exercise.entries.length}',
                    Icons.event_available,
                  ),
                ],
        ),
        const SizedBox(height: 20),
        _SectionCard(
          title: 'Performance trend',
          subtitle: exercise.isCardio
              ? 'Cardio efforts keep time, speed, incline, distance, and added load.'
              : exercise.isTimed
              ? 'Duration from each completed timed movement.'
              : exercise.hasWeight
              ? 'Estimated 1RM uses the Epley formula and is not a max-lift instruction.'
              : 'Completed reps from each workout session.',
          actions: [
            for (final item in availableMetrics)
              ChoiceChip(
                label: Text(_metricLabel(item)),
                selected: _metric == item,
                onSelected: (_) => setState(() => _metric = item),
              ),
          ],
          child: SizedBox(
            height: 210,
            child: _ExerciseTrendChart(exercise: exercise, metric: _metric),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle(title: 'Exercise history'),
        const SizedBox(height: 8),
        ...exercise.entries.reversed
            .take(12)
            .map(
              (entry) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.history)),
                  title: Text(
                    exercise.isCardio
                        ? '${_duration(entry.durationSeconds)} · ${_number(entry.bestSpeedKph)} km/h · ${_number(entry.bestInclinePercent)}% incline'
                        : exercise.isTimed
                        ? _duration(entry.durationSeconds)
                        : entry.weightKg == null
                        ? '${entry.completedSets} sets × ${entry.repsPerSet} reps'
                        : '${entry.completedSets} × ${entry.repsPerSet} at ${_number(entry.weightKg!)} kg',
                  ),
                  subtitle: Text(
                    DateFormat('dd MMM yyyy, h:mm a').format(entry.completedAt),
                  ),
                  trailing: entry.volumeKg > 0
                      ? Text(_compactWeight(entry.volumeKg))
                      : null,
                ),
              ),
            ),
      ],
    );
  }
}

class _BodySection extends StatelessWidget {
  const _BodySection({required this.measurements, required this.photoPaths});

  final List<_BodyMeasurement> measurements;
  final List<String> photoPaths;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (measurements.isEmpty)
        const _EmptyProgress(
          icon: Icons.monitor_weight_outlined,
          title: 'Start a body trend',
          message:
              'Log weight periodically under similar conditions. Daily fluctuations are normal.',
        )
      else ...[
        _BodySnapshot(measurements: measurements),
        const SizedBox(height: 20),
        _SectionCard(
          title: 'Weight trend',
          subtitle: 'A trend is more useful than any single measurement.',
          child: SizedBox(
            height: 220,
            child: _MeasurementChart(
              measurements: measurements,
              value: (item) => item.weightKg,
            ),
          ),
        ),
        if (measurements.any((item) => item.bodyFatPercent != null)) ...[
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Body-fat trend',
            subtitle:
                'Consumer measurements are estimates; compare consistent methods.',
            child: SizedBox(
              height: 220,
              child: _MeasurementChart(
                measurements: measurements
                    .where((item) => item.bodyFatPercent != null)
                    .toList(),
                value: (item) => item.bodyFatPercent!,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const _SectionTitle(title: 'Measurement history'),
        ...measurements.reversed
            .take(12)
            .map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.monitor_weight_outlined),
                ),
                title: Text('${_number(item.weightKg)} kg'),
                subtitle: Text(
                  DateFormat('dd MMM yyyy').format(item.measuredAt),
                ),
                trailing: item.bodyFatPercent == null
                    ? null
                    : Text('${_number(item.bodyFatPercent!)}% body fat'),
              ),
            ),
      ],
      const SizedBox(height: 22),
      const _SectionTitle(
        title: 'Private progress photos',
        trailing: 'Visible only in your gym account',
      ),
      const SizedBox(height: 10),
      if (photoPaths.isEmpty)
        const Text('No progress photos yet.')
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.sizeOf(context).width > 900 ? 4 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: photoPaths.length,
          itemBuilder: (context, index) =>
              _PrivateProgressPhoto(storagePath: photoPaths[index]),
        ),
    ],
  );
}

class _WeeklyWorkoutChart extends StatelessWidget {
  const _WeeklyWorkoutChart({required this.progress});

  final MemberWorkoutProgress progress;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfThisWeek = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );
    final counts = List<int>.filled(8, 0);
    for (final session in progress.sessions) {
      final days = startOfThisWeek.difference(session.completedAt).inDays;
      final weeksAgo = days < 0 ? 0 : days ~/ 7;
      if (weeksAgo >= 0 && weeksAgo < 8) counts[7 - weeksAgo]++;
    }
    final maxValue = counts.fold<int>(
      1,
      (max, value) => value > max ? value : max,
    );
    final color = Theme.of(context).colorScheme.primary;
    return BarChart(
      BarChartData(
        maxY: (maxValue + 1).toDouble(),
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  value.toInt() == 7 ? 'Now' : '${7 - value.toInt()}w',
                ),
              ),
            ),
          ),
        ),
        barGroups: [
          for (var index = 0; index < counts.length; index++)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: counts[index].toDouble(),
                  width: 18,
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExerciseTrendChart extends StatelessWidget {
  const _ExerciseTrendChart({required this.exercise, required this.metric});

  final ExerciseProgressSummary exercise;
  final _ExerciseMetric metric;

  @override
  Widget build(BuildContext context) {
    final entries = exercise.entries.length > 20
        ? exercise.entries.sublist(exercise.entries.length - 20)
        : exercise.entries;
    final spots = entries.indexed
        .map((item) => FlSpot(item.$1.toDouble(), _value(item.$2)))
        .toList(growable: false);
    return _ProgressLineChart(spots: spots);
  }

  double _value(WorkoutProgressEntry entry) => switch (metric) {
    _ExerciseMetric.weight => entry.weightKg ?? 0,
    _ExerciseMetric.estimatedMax => entry.estimatedOneRepMaxKg ?? 0,
    _ExerciseMetric.volume => entry.volumeKg,
    _ExerciseMetric.reps => entry.totalReps.toDouble(),
    _ExerciseMetric.duration => entry.durationSeconds / 60,
    _ExerciseMetric.speed => entry.bestSpeedKph,
    _ExerciseMetric.distance => entry.distanceKm,
  };
}

class _MeasurementChart extends StatelessWidget {
  const _MeasurementChart({required this.measurements, required this.value});

  final List<_BodyMeasurement> measurements;
  final double Function(_BodyMeasurement) value;

  @override
  Widget build(BuildContext context) => _ProgressLineChart(
    spots: measurements.indexed
        .map((item) => FlSpot(item.$1.toDouble(), value(item.$2)))
        .toList(growable: false),
  );
}

class _ProgressLineChart extends StatelessWidget {
  const _ProgressLineChart({required this.spots});

  final List<FlSpot> spots;

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) return const Center(child: Text('No trend data yet'));
    final color = Theme.of(context).colorScheme.primary;
    return LineChart(
      LineChartData(
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: .5),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 42),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: color,
            barWidth: 3,
            isCurved: spots.length > 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: .12),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodySnapshot extends StatelessWidget {
  const _BodySnapshot({required this.measurements});

  final List<_BodyMeasurement> measurements;

  @override
  Widget build(BuildContext context) {
    final latest = measurements.last;
    final change = measurements.length < 2
        ? null
        : latest.weightKg - measurements.first.weightKg;
    return _MetricGrid(
      metrics: [
        _Metric(
          'Current weight',
          '${_number(latest.weightKg)} kg',
          Icons.monitor_weight,
        ),
        _Metric(
          'Recorded change',
          change == null
              ? '—'
              : '${change >= 0 ? '+' : ''}${_number(change)} kg',
          Icons.swap_vert,
        ),
        _Metric(
          'Body fat',
          latest.bodyFatPercent == null
              ? '—'
              : '${_number(latest.bodyFatPercent!)}%',
          Icons.percent,
        ),
      ],
    );
  }
}

class _PrivateProgressPhoto extends StatefulWidget {
  const _PrivateProgressPhoto({required this.storagePath});

  final String storagePath;

  @override
  State<_PrivateProgressPhoto> createState() => _PrivateProgressPhotoState();
}

class _PrivateProgressPhotoState extends State<_PrivateProgressPhoto> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = context.read<GymMediaRepository>().readPrivatePhoto(
      widget.storagePath,
    );
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Color(0x11000000),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.data == null) {
          return const ColoredBox(
            color: Color(0x11000000),
            child: Center(child: Icon(Icons.broken_image_outlined)),
          );
        }
        return Image.memory(snapshot.data!, fit: BoxFit.cover);
      },
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? metrics.length.clamp(1, 4)
          : constraints.maxWidth >= 520
          ? 2
          : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 112,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: metrics.length,
        itemBuilder: (context, index) {
          final metric = metrics[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(child: Icon(metric.icon)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric.value,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(metric.label),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          Text(subtitle),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (trailing != null) Text(trailing!),
    ],
  );
}

class _EmptyProgress extends StatelessWidget {
  const _EmptyProgress({
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
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 46),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class _BodyMeasurement {
  const _BodyMeasurement({
    required this.id,
    required this.measuredAt,
    required this.weightKg,
    required this.bodyFatPercent,
  });

  final String id;
  final DateTime measuredAt;
  final double weightKg;
  final double? bodyFatPercent;
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

String _metricLabel(_ExerciseMetric metric) => switch (metric) {
  _ExerciseMetric.weight => 'Weight',
  _ExerciseMetric.estimatedMax => 'Estimated 1RM',
  _ExerciseMetric.volume => 'Volume',
  _ExerciseMetric.reps => 'Reps',
  _ExerciseMetric.duration => 'Minutes',
  _ExerciseMetric.speed => 'Speed',
  _ExerciseMetric.distance => 'Distance',
};

String _number(num value) => value.toStringAsFixed(value % 1 == 0 ? 0 : 1);

String _compactWeight(double value) {
  if (value >= 1000) return '${_number(value / 1000)}k kg';
  return '${_number(value)} kg';
}

String _duration(int seconds) {
  if (seconds <= 0) return '—';
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  if (minutes == 0) return '${remainder}s';
  return remainder == 0 ? '${minutes}m' : '${minutes}m ${remainder}s';
}
