enum MovementTrackingType {
  strength('Strength', 'Weight and reps'),
  bodyweight('Bodyweight', 'Reps and optional added load'),
  cardio('Cardio', 'Time, speed, incline, and distance'),
  timed('Timed movement', 'Duration and optional load');

  const MovementTrackingType(this.label, this.description);

  final String label;
  final String description;

  static MovementTrackingType fromName(Object? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => MovementTrackingType.strength,
  );
}

class RoutineMovement {
  const RoutineMovement({
    required this.id,
    required this.name,
    required this.trackingType,
    required this.targetSets,
    this.exerciseId,
    this.notes = '',
  });

  final String id;
  final String? exerciseId;
  final String name;
  final MovementTrackingType trackingType;
  final int targetSets;
  final String notes;

  Map<String, dynamic> toMap() => {
    'id': id,
    if (exerciseId != null) 'exerciseId': exerciseId,
    'name': name,
    'trackingType': trackingType.name,
    'targetSets': targetSets,
    if (notes.isNotEmpty) 'notes': notes,
  };

  factory RoutineMovement.fromMap(Map<String, dynamic> data) => RoutineMovement(
    id: '${data['id'] ?? data['exerciseId'] ?? data['name'] ?? 'movement'}',
    exerciseId: data['exerciseId'] as String?,
    name: '${data['name'] ?? 'Movement'}',
    trackingType: MovementTrackingType.fromName(data['trackingType']),
    targetSets: ((data['targetSets'] as num?)?.toInt() ?? 1).clamp(1, 20),
    notes: '${data['notes'] ?? ''}',
  );
}

class MemberRoutine {
  const MemberRoutine({
    required this.id,
    required this.name,
    required this.scheduledWeekdays,
    required this.movements,
    required this.status,
  });

  final String id;
  final String name;
  final List<int> scheduledWeekdays;
  final List<RoutineMovement> movements;
  final String status;

  factory MemberRoutine.fromMap(String id, Map<String, dynamic> data) =>
      MemberRoutine(
        id: id,
        name: '${data['name'] ?? 'My routine'}',
        scheduledWeekdays:
            (data['scheduledWeekdays'] as List?)
                ?.whereType<num>()
                .map((value) => value.toInt())
                .where((value) => value >= 1 && value <= 7)
                .toList(growable: false) ??
            const [],
        movements:
            (data['movements'] as List?)
                ?.whereType<Map>()
                .map(
                  (value) =>
                      RoutineMovement.fromMap(Map<String, dynamic>.from(value)),
                )
                .toList(growable: false) ??
            const [],
        status: '${data['status'] ?? 'active'}',
      );
}

class LoggedMovementSet {
  const LoggedMovementSet({
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

  bool get hasData =>
      reps != null ||
      weightKg != null ||
      additionalLoadKg != null ||
      durationSeconds != null ||
      speedKph != null ||
      inclinePercent != null ||
      distanceKm != null;

  Map<String, dynamic> toMap(int setNumber) => {
    'setNumber': setNumber,
    if (reps != null) 'reps': reps,
    if (weightKg != null) 'weightKg': weightKg,
    if (additionalLoadKg != null) 'additionalLoadKg': additionalLoadKg,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (speedKph != null) 'speedKph': speedKph,
    if (inclinePercent != null) 'inclinePercent': inclinePercent,
    if (distanceKm != null) 'distanceKm': distanceKm,
  };
}
