part of 'fitness_goals_bloc.dart';

@immutable
abstract class FitnessGoalsState extends Equatable {
  const FitnessGoalsState();

  @override
  List<Object?> get props => [];
}

class FitnessGoalsInitial extends FitnessGoalsState {}

class FitnessGoalsLoading extends FitnessGoalsState {}

class FitnessGoalsLoaded extends FitnessGoalsState {
  final FitnessGoals goals;

  const FitnessGoalsLoaded(this.goals);

  @override
  List<Object?> get props => [goals];
}

class FitnessGoalsUpdateSuccess extends FitnessGoalsState {}

class FitnessGoalsError extends FitnessGoalsState {
  final String message;

  const FitnessGoalsError(this.message);

  @override
  List<Object?> get props => [message];
}
