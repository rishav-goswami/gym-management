part of 'fitness_goals_bloc.dart';

@immutable
abstract class FitnessGoalsEvent extends Equatable {
  const FitnessGoalsEvent();

  @override
  List<Object?> get props => [];
}

class LoadFitnessGoals extends FitnessGoalsEvent {}

class UpdateFitnessGoals extends FitnessGoalsEvent {
  final String? primaryGoalId; // Now expects ID
  final String? workoutFrequencyId; // Now expects ID
  final Set<String> preferredWorkoutIds; // Now expects IDs

  const UpdateFitnessGoals({
    this.primaryGoalId,
    this.workoutFrequencyId,
    this.preferredWorkoutIds = const {},
  });

  @override
  List<Object?> get props => [
    primaryGoalId,
    workoutFrequencyId,
    preferredWorkoutIds,
  ];
}

class LoadFitnessGoalsOptions extends FitnessGoalsEvent {} // New event

// SearchWorkoutsEvent no longer needs `token`
class SearchWorkoutsEvent extends FitnessGoalsEvent {
  final String query;
  const SearchWorkoutsEvent({required this.query});

  @override
  List<Object?> get props => [query];
}

// New event to explicitly clear workout search results
class ClearWorkoutSearchResultsEvent extends FitnessGoalsEvent {
  const ClearWorkoutSearchResultsEvent();
  @override
  List<Object?> get props => [];
}
