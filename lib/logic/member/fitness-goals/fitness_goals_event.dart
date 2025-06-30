part of 'fitness_goals_bloc.dart';

@immutable
abstract class FitnessGoalsEvent extends Equatable {
  const FitnessGoalsEvent();

  @override
  List<Object?> get props => [];
}

class LoadFitnessGoals extends FitnessGoalsEvent {}

class UpdateFitnessGoals extends FitnessGoalsEvent {
  final String? primaryGoal;
  final String? workoutFrequency;
  final Set<String> preferredWorkouts;

  const UpdateFitnessGoals({
    this.primaryGoal,
    this.workoutFrequency,
    required this.preferredWorkouts,
  });

  @override
  List<Object?> get props => [primaryGoal, workoutFrequency, preferredWorkouts];
}
