import 'package:flutter/foundation.dart';

// ===================
// The Exercise Model (from the Library)
// ===================
@immutable
class Exercise {
  final String id;
  final String name;
  final String? description;
  final String muscleGroup;
  final String? videoUrl;

  const Exercise({
    required this.id,
    required this.name,
    this.description,
    required this.muscleGroup,
    this.videoUrl,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['_id'],
      name: json['name'],
      description: json['description'],
      muscleGroup: json['muscleGroup'],
      videoUrl: json['videoUrl'],
    );
  }
}

// ===================
// The Workout Plan Model (Assigned to a User)
// ===================

// A single exercise within a day's plan
@immutable
class AssignedExercise {
  final String exerciseId;
  final String name; // Denormalized name for easy display
  final int sets;
  final String reps;
  final String rest;
  final String? notes;

  const AssignedExercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
    required this.reps,
    required this.rest,
    this.notes,
  });

  // Factory constructor to create an instance from JSON
  factory AssignedExercise.fromJson(Map<String, dynamic> json) {
    // This handles the populated 'exerciseId' field from your backend
    final exerciseData = json['exerciseId'] as Map<String, dynamic>?;

    return AssignedExercise(
      exerciseId:
          exerciseData?['_id'] ??
          json['exerciseId'], // Fallback if not populated
      name: exerciseData?['name'] ?? 'Unknown Exercise', // Use populated name
      sets: json['sets'],
      reps: json['reps'],
      rest: json['rest'],
      notes: json['notes'],
    );
  }
}

// A full day's worth of exercises
@immutable
class DailyWorkout {
  final String day; // e.g., "Monday"
  final List<AssignedExercise> exercises;

  const DailyWorkout({required this.day, required this.exercises});

  // Factory constructor to create an instance from JSON
  factory DailyWorkout.fromJson(Map<String, dynamic> json) {
    var exerciseList = <AssignedExercise>[];
    if (json['exercises'] != null) {
      json['exercises'].forEach((v) {
        exerciseList.add(AssignedExercise.fromJson(v));
      });
    }
    return DailyWorkout(day: json['day'], exercises: exerciseList);
  }
}

// The complete weekly workout plan
@immutable
class WorkoutPlan {
  final String id;
  final String userId;
  final DateTime weekStartDate;
  final List<DailyWorkout> days;

  const WorkoutPlan({
    required this.id,
    required this.userId,
    required this.weekStartDate,
    required this.days,
  });

  // Factory constructor to create an instance from JSON
  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    var dayList = <DailyWorkout>[];
    if (json['days'] != null) {
      json['days'].forEach((v) {
        dayList.add(DailyWorkout.fromJson(v));
      });
    }
    return WorkoutPlan(
      id: json['_id'],
      userId: json['userId'],
      weekStartDate: DateTime.parse(json['weekStartDate']),
      days: dayList,
    );
  }
}
