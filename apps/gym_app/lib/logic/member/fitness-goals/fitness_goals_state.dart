part of 'fitness_goals_bloc.dart';

@immutable
abstract class FitnessGoalsState extends Equatable {
  final List<OptionItem> healthGoalOptions;
  final List<OptionItem> workoutFrequencyOptions;
  final bool isOptionsLoading; // For initial loading of all options

  final bool isWorkoutSearchLoading; // For workout search specifically
  final List<OptionItem> workoutSearchResults;
  final String? workoutSearchError;

  const FitnessGoalsState({
    this.healthGoalOptions = const [],
    this.workoutFrequencyOptions = const [],
    this.isOptionsLoading = false,
    this.isWorkoutSearchLoading = false,
    this.workoutSearchResults = const [],
    this.workoutSearchError,
  });

  // Abstract copyWith method to be implemented by concrete states
  FitnessGoalsState copyWith({
    List<OptionItem>? healthGoalOptions,
    List<OptionItem>? workoutFrequencyOptions,
    bool? isOptionsLoading,
    bool? isWorkoutSearchLoading,
    List<OptionItem>? workoutSearchResults,
    String? workoutSearchError,
  });

  @override
  List<Object?> get props => [
    healthGoalOptions,
    workoutFrequencyOptions,
    isOptionsLoading,
    isWorkoutSearchLoading,
    workoutSearchResults,
    workoutSearchError,
  ];
}

class FitnessGoalsInitial extends FitnessGoalsState {
  const FitnessGoalsInitial({
    super.healthGoalOptions,
    super.workoutFrequencyOptions,
    super.isOptionsLoading,
    super.isWorkoutSearchLoading,
    super.workoutSearchResults,
    super.workoutSearchError,
  });

  @override
  FitnessGoalsInitial copyWith({
    List<OptionItem>? healthGoalOptions,
    List<OptionItem>? workoutFrequencyOptions,
    bool? isOptionsLoading,
    bool? isWorkoutSearchLoading,
    List<OptionItem>? workoutSearchResults,
    String? workoutSearchError,
  }) {
    return FitnessGoalsInitial(
      healthGoalOptions: healthGoalOptions ?? this.healthGoalOptions,
      workoutFrequencyOptions:
          workoutFrequencyOptions ?? this.workoutFrequencyOptions,
      isOptionsLoading: isOptionsLoading ?? this.isOptionsLoading,
      isWorkoutSearchLoading:
          isWorkoutSearchLoading ?? this.isWorkoutSearchLoading,
      workoutSearchResults: workoutSearchResults ?? this.workoutSearchResults,
      workoutSearchError: workoutSearchError,
    );
  }
}

// Global loading state (for initial screen load or update)
class FitnessGoalsLoading extends FitnessGoalsState {
  const FitnessGoalsLoading({
    super.healthGoalOptions,
    super.workoutFrequencyOptions,
    super.isOptionsLoading,
    super.isWorkoutSearchLoading,
    super.workoutSearchResults,
    super.workoutSearchError,
  });

  @override
  FitnessGoalsLoading copyWith({
    List<OptionItem>? healthGoalOptions,
    List<OptionItem>? workoutFrequencyOptions,
    bool? isOptionsLoading,
    bool? isWorkoutSearchLoading,
    List<OptionItem>? workoutSearchResults,
    String? workoutSearchError,
  }) {
    return FitnessGoalsLoading(
      healthGoalOptions: healthGoalOptions ?? this.healthGoalOptions,
      workoutFrequencyOptions:
          workoutFrequencyOptions ?? this.workoutFrequencyOptions,
      isOptionsLoading: isOptionsLoading ?? this.isOptionsLoading,
      isWorkoutSearchLoading:
          isWorkoutSearchLoading ?? this.isWorkoutSearchLoading,
      workoutSearchResults: workoutSearchResults ?? this.workoutSearchResults,
      workoutSearchError: workoutSearchError,
    );
  }
}

class FitnessGoalsLoaded extends FitnessGoalsState {
  final FitnessGoals goals;

  const FitnessGoalsLoaded(
    this.goals, {
    super.healthGoalOptions,
    super.workoutFrequencyOptions,
    super.isOptionsLoading,
    super.isWorkoutSearchLoading,
    super.workoutSearchResults,
    super.workoutSearchError,
  });

  @override
  FitnessGoalsLoaded copyWith({
    FitnessGoals? goals,
    List<OptionItem>? healthGoalOptions,
    List<OptionItem>? workoutFrequencyOptions,
    bool? isOptionsLoading,
    bool? isWorkoutSearchLoading,
    List<OptionItem>? workoutSearchResults,
    String? workoutSearchError,
  }) {
    return FitnessGoalsLoaded(
      goals ?? this.goals,
      healthGoalOptions: healthGoalOptions ?? this.healthGoalOptions,
      workoutFrequencyOptions:
          workoutFrequencyOptions ?? this.workoutFrequencyOptions,
      isOptionsLoading: isOptionsLoading ?? this.isOptionsLoading,
      isWorkoutSearchLoading:
          isWorkoutSearchLoading ?? this.isWorkoutSearchLoading,
      workoutSearchResults: workoutSearchResults ?? this.workoutSearchResults,
      workoutSearchError: workoutSearchError,
    );
  }

  @override
  List<Object?> get props => [
    goals,
    healthGoalOptions,
    workoutFrequencyOptions,
    isOptionsLoading,
    isWorkoutSearchLoading,
    workoutSearchResults,
    workoutSearchError,
  ];
}

class FitnessGoalsUpdateSuccess extends FitnessGoalsState {
  // This state is transient. It typically doesn't hold search results,
  // but if it needs to preserve them, it should also have these fields.
  const FitnessGoalsUpdateSuccess({
    super.healthGoalOptions,
    super.workoutFrequencyOptions,
    super.isOptionsLoading,
    super.isWorkoutSearchLoading,
    super.workoutSearchResults,
    super.workoutSearchError,
  });

  @override
  FitnessGoalsUpdateSuccess copyWith({
    List<OptionItem>? healthGoalOptions,
    List<OptionItem>? workoutFrequencyOptions,
    bool? isOptionsLoading,
    bool? isWorkoutSearchLoading,
    List<OptionItem>? workoutSearchResults,
    String? workoutSearchError,
  }) {
    return FitnessGoalsUpdateSuccess(
      healthGoalOptions: healthGoalOptions ?? this.healthGoalOptions,
      workoutFrequencyOptions:
          workoutFrequencyOptions ?? this.workoutFrequencyOptions,
      isOptionsLoading: isOptionsLoading ?? this.isOptionsLoading,
      isWorkoutSearchLoading:
          isWorkoutSearchLoading ?? this.isWorkoutSearchLoading,
      workoutSearchResults: workoutSearchResults ?? this.workoutSearchResults,
      workoutSearchError: workoutSearchError,
    );
  }
}

class FitnessGoalsError extends FitnessGoalsState {
  final String message;

  const FitnessGoalsError(
    this.message, {
    super.healthGoalOptions,
    super.workoutFrequencyOptions,
    super.isOptionsLoading,
    super.isWorkoutSearchLoading,
    super.workoutSearchResults,
    super.workoutSearchError,
  });

  @override
  FitnessGoalsError copyWith({
    String? message,
    List<OptionItem>? healthGoalOptions,
    List<OptionItem>? workoutFrequencyOptions,
    bool? isOptionsLoading,
    bool? isWorkoutSearchLoading,
    List<OptionItem>? workoutSearchResults,
    String? workoutSearchError,
  }) {
    return FitnessGoalsError(
      message ?? this.message,
      healthGoalOptions: healthGoalOptions ?? this.healthGoalOptions,
      workoutFrequencyOptions:
          workoutFrequencyOptions ?? this.workoutFrequencyOptions,
      isOptionsLoading: isOptionsLoading ?? this.isOptionsLoading,
      isWorkoutSearchLoading:
          isWorkoutSearchLoading ?? this.isWorkoutSearchLoading,
      workoutSearchResults: workoutSearchResults ?? this.workoutSearchResults,
      workoutSearchError: workoutSearchError,
    );
  }

  @override
  List<Object?> get props => [
    message,
    healthGoalOptions,
    workoutFrequencyOptions,
    isOptionsLoading,
    isWorkoutSearchLoading,
    workoutSearchResults,
    workoutSearchError,
  ];
}
