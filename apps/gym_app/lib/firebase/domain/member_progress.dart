class WorkoutSetProgress {
  const WorkoutSetProgress({
    this.reps,
    this.weightKg,
    this.additionalLoadKg,
    this.durationSeconds,
    this.speedKph,
    this.inclinePercent,
    this.distanceKm,
  });

  final int? reps;
  final double? weightKg;
  final double? additionalLoadKg;
  final int? durationSeconds;
  final double? speedKph;
  final double? inclinePercent;
  final double? distanceKm;

  double get volumeKg => (weightKg ?? additionalLoadKg ?? 0) * (reps ?? 0);
  double? get estimatedOneRepMaxKg =>
      weightKg == null || reps == null ? null : weightKg! * (1 + reps! / 30);
}

class WorkoutProgressEntry {
  const WorkoutProgressEntry({
    required this.workoutId,
    required this.exerciseId,
    required this.exerciseName,
    required this.completedAt,
    required this.completedSets,
    required this.repsPerSet,
    required this.weightKg,
    this.trackingType = 'strength',
    this.sets = const [],
  });

  final String workoutId;
  final String exerciseId;
  final String exerciseName;
  final DateTime completedAt;
  final int completedSets;
  final int repsPerSet;
  final double? weightKg;
  final String trackingType;
  final List<WorkoutSetProgress> sets;

  int get totalReps => sets.isEmpty
      ? completedSets * repsPerSet
      : sets.fold(0, (total, set) => total + (set.reps ?? 0));
  int get bestSetReps => sets.isEmpty
      ? repsPerSet
      : sets.fold(0, (best, set) => (set.reps ?? 0) > best ? set.reps! : best);
  double get bestWeightKg => sets.isEmpty
      ? weightKg ?? 0
      : sets.fold(
          0,
          (best, set) => (set.weightKg ?? 0) > best ? set.weightKg! : best,
        );
  double get volumeKg => sets.isEmpty
      ? (weightKg ?? 0) * totalReps
      : sets.fold(0, (total, set) => total + set.volumeKg);
  double? get estimatedOneRepMaxKg {
    if (sets.isEmpty) {
      return weightKg == null || repsPerSet <= 0
          ? null
          : weightKg! * (1 + repsPerSet / 30);
    }
    final best = sets.fold(0.0, (value, set) {
      final estimate = set.estimatedOneRepMaxKg ?? 0;
      return estimate > value ? estimate : value;
    });
    return best == 0 ? null : best;
  }

  int get durationSeconds =>
      sets.fold(0, (total, set) => total + (set.durationSeconds ?? 0));
  double get distanceKm =>
      sets.fold(0, (total, set) => total + (set.distanceKm ?? 0));
  double get bestSpeedKph => sets.fold(
    0,
    (best, set) => (set.speedKph ?? 0) > best ? set.speedKph! : best,
  );
  double get bestInclinePercent => sets.fold(
    0,
    (best, set) =>
        (set.inclinePercent ?? 0) > best ? set.inclinePercent! : best,
  );
}

class WorkoutProgressSession {
  const WorkoutProgressSession({
    required this.id,
    required this.title,
    required this.completedAt,
    required this.durationSeconds,
    required this.entries,
  });

  final String id;
  final String title;
  final DateTime completedAt;
  final int durationSeconds;
  final List<WorkoutProgressEntry> entries;

  int get completedSets =>
      entries.fold(0, (total, item) => total + item.completedSets);
  double get volumeKg =>
      entries.fold(0, (total, item) => total + item.volumeKg);
}

class ExerciseProgressSummary {
  const ExerciseProgressSummary({
    required this.exerciseId,
    required this.exerciseName,
    required this.entries,
  });

  final String exerciseId;
  final String exerciseName;
  final List<WorkoutProgressEntry> entries;

  bool get hasWeight => entries.any((entry) => entry.weightKg != null);
  bool get isCardio => entries.any((entry) => entry.trackingType == 'cardio');
  bool get isTimed => entries.any((entry) => entry.trackingType == 'timed');
  double get bestWeightKg => entries.fold(
    0,
    (best, entry) => entry.bestWeightKg > best ? entry.bestWeightKg : best,
  );
  int get bestSetReps => entries.fold(
    0,
    (best, entry) => entry.bestSetReps > best ? entry.bestSetReps : best,
  );
  int get bestSessionReps => entries.fold(
    0,
    (best, entry) => entry.totalReps > best ? entry.totalReps : best,
  );
  double get bestSessionVolumeKg => entries.fold(
    0,
    (best, entry) => entry.volumeKg > best ? entry.volumeKg : best,
  );
  double get bestEstimatedOneRepMaxKg => entries.fold(0, (best, entry) {
    final value = entry.estimatedOneRepMaxKg ?? 0;
    return value > best ? value : best;
  });
  int get bestDurationSeconds => entries.fold(
    0,
    (best, entry) =>
        entry.durationSeconds > best ? entry.durationSeconds : best,
  );
  double get bestSpeedKph => entries.fold(
    0,
    (best, entry) => entry.bestSpeedKph > best ? entry.bestSpeedKph : best,
  );
  double get longestDistanceKm => entries.fold(
    0,
    (best, entry) => entry.distanceKm > best ? entry.distanceKm : best,
  );
  double get bestInclinePercent => entries.fold(
    0,
    (best, entry) =>
        entry.bestInclinePercent > best ? entry.bestInclinePercent : best,
  );
  DateTime get lastPerformedAt => entries.last.completedAt;
}

class MemberWorkoutProgress {
  const MemberWorkoutProgress({
    required this.sessions,
    required this.exercises,
  });

  factory MemberWorkoutProgress.fromLogs(
    Iterable<({String id, Map<String, dynamic> data})> logs,
  ) {
    final sessions = <WorkoutProgressSession>[];
    for (final log in logs) {
      final completedAt = log.data['completedAt'];
      if (completedAt is! DateTime) continue;
      final entries = <WorkoutProgressEntry>[];
      final rawExercises = log.data['exercises'];
      if (rawExercises is List) {
        for (final raw in rawExercises) {
          if (raw is! Map) continue;
          final data = Map<String, dynamic>.from(raw);
          final completedSets = (data['completedSets'] as num?)?.toInt() ?? 0;
          if (completedSets <= 0) continue;
          final sets =
              (data['sets'] as List?)
                  ?.whereType<Map>()
                  .map((value) {
                    final set = Map<String, dynamic>.from(value);
                    return WorkoutSetProgress(
                      reps: (set['reps'] as num?)?.toInt(),
                      weightKg: (set['weightKg'] as num?)?.toDouble(),
                      additionalLoadKg: (set['additionalLoadKg'] as num?)
                          ?.toDouble(),
                      durationSeconds: (set['durationSeconds'] as num?)
                          ?.toInt(),
                      speedKph: (set['speedKph'] as num?)?.toDouble(),
                      inclinePercent: (set['inclinePercent'] as num?)
                          ?.toDouble(),
                      distanceKm: (set['distanceKm'] as num?)?.toDouble(),
                    );
                  })
                  .toList(growable: false) ??
              const <WorkoutSetProgress>[];
          entries.add(
            WorkoutProgressEntry(
              workoutId: log.id,
              exerciseId: '${data['exerciseId'] ?? data['name'] ?? 'exercise'}',
              exerciseName: '${data['name'] ?? 'Exercise'}',
              completedAt: completedAt,
              completedSets: completedSets,
              repsPerSet:
                  (data['repsPerSet'] as num?)?.toInt() ??
                  parseFirstPositiveInteger(data['targetReps']) ??
                  0,
              weightKg: (data['weightKg'] as num?)?.toDouble(),
              trackingType: '${data['trackingType'] ?? 'strength'}',
              sets: sets,
            ),
          );
        }
      }
      sessions.add(
        WorkoutProgressSession(
          id: log.id,
          title: '${log.data['title'] ?? 'Workout'}',
          completedAt: completedAt,
          durationSeconds: (log.data['durationSeconds'] as num?)?.toInt() ?? 0,
          entries: entries,
        ),
      );
    }
    sessions.sort(
      (left, right) => left.completedAt.compareTo(right.completedAt),
    );
    final byExercise = <String, List<WorkoutProgressEntry>>{};
    for (final session in sessions) {
      for (final entry in session.entries) {
        byExercise.putIfAbsent(entry.exerciseId, () => []).add(entry);
      }
    }
    final exercises =
        byExercise.entries
            .map(
              (item) => ExerciseProgressSummary(
                exerciseId: item.key,
                exerciseName: item.value.last.exerciseName,
                entries: item.value,
              ),
            )
            .toList()
          ..sort(
            (left, right) =>
                right.lastPerformedAt.compareTo(left.lastPerformedAt),
          );
    return MemberWorkoutProgress(sessions: sessions, exercises: exercises);
  }

  final List<WorkoutProgressSession> sessions;
  final List<ExerciseProgressSummary> exercises;

  List<WorkoutProgressSession> since(DateTime date) =>
      sessions.where((session) => !session.completedAt.isBefore(date)).toList();
}

int? parseFirstPositiveInteger(Object? value) {
  if (value is num && value > 0) return value.toInt();
  final match = RegExp(r'\d+').firstMatch('$value');
  final parsed = match == null ? null : int.tryParse(match.group(0)!);
  return parsed == null || parsed <= 0 ? null : parsed;
}
