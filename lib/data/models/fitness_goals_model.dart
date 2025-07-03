import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'; // For listEquals in Equatable if used there

@immutable
class OptionItem extends Equatable {
  final String id;
  final String name;

  const OptionItem({required this.id, required this.name});

  factory OptionItem.fromJson(Map<String, dynamic> json) {
    return OptionItem(id: json['id'] as String, name: json['name'] as String);
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  List<Object?> get props => [id, name];
}

@immutable
class FitnessGoals extends Equatable {
  final String? id; // User ID
  final OptionItem? healthGoals; // Now an OptionItem
  final OptionItem? workoutFrequency; // Now an OptionItem
  final List<OptionItem> preferredWorkouts; // Now a list of OptionItem
  final String? preferredWorkoutTime;

  const FitnessGoals({
    this.id,
    this.healthGoals,
    this.workoutFrequency,
    this.preferredWorkouts = const [],
    this.preferredWorkoutTime,
  });

  factory FitnessGoals.fromJson(Map<String, dynamic> json) {
    // Handle parsing of nested objects and arrays for populated fields
    final healthGoalsJson = json['healthGoals'];
    final workoutFrequencyJson = json['workoutFrequency'];
    final preferredWorkoutsList = json['preferredWorkouts'] as List?;

    return FitnessGoals(
      id: json['_id'] as String?,
      healthGoals: healthGoalsJson != null
          ? OptionItem.fromJson(healthGoalsJson as Map<String, dynamic>)
          : null,
      workoutFrequency: workoutFrequencyJson != null
          ? OptionItem.fromJson(workoutFrequencyJson as Map<String, dynamic>)
          : null,
      preferredWorkouts: preferredWorkoutsList != null
          ? preferredWorkoutsList
                .map(
                  (item) => OptionItem.fromJson(item as Map<String, dynamic>),
                )
                .toList()
          : <OptionItem>[],
      preferredWorkoutTime: json['preferredWorkoutTime'] as String?,
    );
  }

  // toJson needs to send back IDs, not full objects, for updates
  Map<String, dynamic> toJson() => {
    '_id': id,
    'healthGoals': healthGoals?.id, // Send back ID
    'workoutFrequency': workoutFrequency?.id, // Send back ID
    'preferredWorkouts': preferredWorkouts
        .map((item) => item.id)
        .toList(), // Send back list of IDs
    'preferredWorkoutTime': preferredWorkoutTime,
  }..removeWhere((k, v) => v == null);

  @override
  List<Object?> get props => [
    id,
    healthGoals,
    workoutFrequency,
    preferredWorkouts,
    preferredWorkoutTime,
  ];
}
