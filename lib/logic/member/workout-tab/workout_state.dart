part of 'workout_bloc.dart';

abstract class WorkoutState extends Equatable {
  const WorkoutState();
  @override
  List<Object?> get props => []; // Allow nulls in props
}

class WorkoutInitial extends WorkoutState {}

class WorkoutLoading extends WorkoutState {}

/// The successful state, holding all the data for the UI.
class WorkoutLoaded extends WorkoutState {
  /// The workout plan can be null if the user has no assigned plan.
  /// This allows the UI to handle cases where no plan is assigned.
  final WorkoutPlan? workoutPlan;
  final List<Exercise> exerciseLibrary;

  const WorkoutLoaded({ this.workoutPlan, required this.exerciseLibrary});

  @override
  List<Object?> get props => [workoutPlan, exerciseLibrary];
}

class WorkoutError extends WorkoutState {
  final String message;
  const WorkoutError(this.message);
  @override
  List<Object> get props => [message];
}
