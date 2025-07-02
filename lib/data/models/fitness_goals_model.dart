import 'package:flutter/foundation.dart';

@immutable
class FitnessGoals {
  final String? id;
  final String? healthGoals;
  final String? workoutFrequency;
  final List<String> preferredWorkouts;
  final String? preferredWorkoutTime;

  const FitnessGoals({
    this.id,
    this.healthGoals,
    this.workoutFrequency,
    this.preferredWorkouts = const [],
    this.preferredWorkoutTime,
  });

  factory FitnessGoals.fromJson(Map<String, dynamic> json) {
    return FitnessGoals(
      id: json['_id'] as String?,
      healthGoals: json['healthGoals'] as String?,
      workoutFrequency: json['workoutFrequency'] as String?,
      preferredWorkouts: (json['preferredWorkouts'] as List?)?.whereType<String>().toList() ?? <String>[],
      preferredWorkoutTime: json['preferredWorkoutTime'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'healthGoals': healthGoals,
        'workoutFrequency': workoutFrequency,
        'preferredWorkouts': preferredWorkouts,
        'preferredWorkoutTime': preferredWorkoutTime,
      }..removeWhere((k, v) => v == null);
}
