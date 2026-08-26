part of 'workout_bloc.dart';

abstract class WorkoutEvent extends Equatable {
  const WorkoutEvent();
  @override
  List<Object> get props => [];
}

/// Dispatched to fetch all data needed for the workouts tab.
class FetchWorkoutData extends WorkoutEvent {}
