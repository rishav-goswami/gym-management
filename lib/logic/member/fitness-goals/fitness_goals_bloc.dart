import 'package:equatable/equatable.dart';
import 'package:fit_and_fine/data/models/fitness_goals_model.dart';
import 'package:fit_and_fine/data/repositories/fitness_goals_repository.dart';
import 'package:flutter/foundation.dart'; // For listEquals
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_state.dart';

part 'fitness_goals_event.dart';
part 'fitness_goals_state.dart';

class FitnessGoalsBloc extends Bloc<FitnessGoalsEvent, FitnessGoalsState> {
  final FitnessGoalsRepository _repository;
  final AuthBloc _authBloc;

  FitnessGoalsBloc({
    required FitnessGoalsRepository repository,
    required AuthBloc authBloc,
  }) : _repository = repository,
       _authBloc = authBloc,
       super(const FitnessGoalsInitial()) {
    // Use const constructor
    on<LoadFitnessGoals>(_onLoadFitnessGoals);
    on<UpdateFitnessGoals>(_onUpdateFitnessGoals);
    on<LoadFitnessGoalsOptions>(_onLoadFitnessGoalsOptions);
    on<SearchWorkoutsEvent>(_onSearchWorkouts);
    on<ClearWorkoutSearchResultsEvent>(_onClearWorkoutSearchResults);
  }

  // Helper to safely get the current state with all the common properties
  // This helps avoid repetitive type checking
  FitnessGoalsState _getCurrentStateWithCommonProps() {
    // Return a copy of the current state, ensuring all search properties are carried over
    if (state is FitnessGoalsLoaded) {
      return (state as FitnessGoalsLoaded);
    } else if (state is FitnessGoalsError) {
      return (state as FitnessGoalsError);
    } else if (state is FitnessGoalsLoading) {
      return (state as FitnessGoalsLoading);
    } else if (state is FitnessGoalsUpdateSuccess) {
      return (state as FitnessGoalsUpdateSuccess);
    }
    return const FitnessGoalsInitial(); // Default fallback
  }

  Future<void> _onLoadFitnessGoalsOptions(
    LoadFitnessGoalsOptions event,
    Emitter<FitnessGoalsState> emit,
  ) async {
    // Start with the current state to preserve existing data, but mark options as loading
    final currentState = _getCurrentStateWithCommonProps();
    emit(currentState.copyWith(isOptionsLoading: true));

    final authState = _authBloc.state;
    if (authState is! AuthAuthenticated) {
      emit(
        currentState.copyWith(
          isOptionsLoading: false,
          workoutSearchError:
              'Not authenticated for options', // Specific error if desired
        ),
      );
      return;
    }
    final token = authState.authModel.accessToken;

    try {
      final healthGoals = await _repository.fetchHealthGoalsOptions(token);
      final workoutFrequencies = await _repository.fetchWorkoutFrequencyOptions(
        token,
      );

      emit(
        currentState.copyWith(
          healthGoalOptions: healthGoals,
          workoutFrequencyOptions: workoutFrequencies,
          isOptionsLoading: false,
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isOptionsLoading: false,
          workoutSearchError: e
              .toString(), // Use workoutSearchError for general options errors for now
        ),
      );
      // You might want a more general `errorMessage` field on the base state
      // if errors can come from sources other than workout search.
    }
  }

  Future<void> _onLoadFitnessGoals(
    LoadFitnessGoals event,
    Emitter<FitnessGoalsState> emit,
  ) async {
    // Only show global loading if the options are *not* already loaded
    // This prevents the screen from flashing a full loader if options are already there.
    final currentState = _getCurrentStateWithCommonProps();
    if (!currentState.isOptionsLoading &&
        currentState.healthGoalOptions.isEmpty) {
      emit(
        currentState.copyWith(isOptionsLoading: true),
      ); // Use isOptionsLoading for initial full load
    }

    final authState = _authBloc.state;
    if (authState is! AuthAuthenticated) {
      emit(
        currentState.copyWith(
          isOptionsLoading: false,
          workoutSearchError: 'Not authenticated for goals',
        ),
      );
      return;
    }
    final token = authState.authModel.accessToken;

    try {
      final goals = await _repository.getFitnessGoals(token);

      // Emit FitnessGoalsLoaded, preserving the options and search state
      emit(
        FitnessGoalsLoaded(
          goals,
          healthGoalOptions: currentState.healthGoalOptions,
          workoutFrequencyOptions: currentState.workoutFrequencyOptions,
          isOptionsLoading: false, // Initial goals are loaded, options too.
          isWorkoutSearchLoading: currentState.isWorkoutSearchLoading,
          workoutSearchResults: currentState.workoutSearchResults,
          workoutSearchError: currentState.workoutSearchError,
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isOptionsLoading: false, // Stop loading indicator
          workoutSearchError: e.toString(),
        ),
      );
    }
  }

  Future<void> _onUpdateFitnessGoals(
    UpdateFitnessGoals event,
    Emitter<FitnessGoalsState> emit,
  ) async {
    final currentState = _getCurrentStateWithCommonProps();
    emit(
      currentState.copyWith(isOptionsLoading: true),
    ); // Use isOptionsLoading for update loading as well

    final authState = _authBloc.state;
    if (authState is! AuthAuthenticated) {
      emit(
        currentState.copyWith(
          isOptionsLoading: false,
          workoutSearchError: 'Not authenticated for update',
        ),
      );
      return;
    }
    final token = authState.authModel.accessToken;

    try {
      final updates = {
        'healthGoals': event.primaryGoalId, // Send ID
        'workoutFrequency': event.workoutFrequencyId, // Send ID
        'preferredWorkouts': event.preferredWorkoutIds.toList(), // Send IDs
        // preferredWorkoutTime: event.preferredWorkoutTime, // Add if you have it
      }..removeWhere((k, v) => v == null);

      final updatedGoals = await _repository.updateFitnessGoals(token, updates);

      emit(
        FitnessGoalsUpdateSuccess(
          // This is a transient state, typically for showing a snackbar
          healthGoalOptions: currentState.healthGoalOptions,
          workoutFrequencyOptions: currentState.workoutFrequencyOptions,
          isOptionsLoading: false,
          isWorkoutSearchLoading: currentState.isWorkoutSearchLoading,
          workoutSearchResults: currentState.workoutSearchResults,
          workoutSearchError: currentState.workoutSearchError,
        ),
      );

      // Immediately follow with the loaded state to reflect the updated goals
      emit(
        FitnessGoalsLoaded(
          updatedGoals,
          healthGoalOptions: currentState.healthGoalOptions,
          workoutFrequencyOptions: currentState.workoutFrequencyOptions,
          isOptionsLoading: false,
          isWorkoutSearchLoading: currentState.isWorkoutSearchLoading,
          workoutSearchResults: currentState.workoutSearchResults,
          workoutSearchError: currentState.workoutSearchError,
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isOptionsLoading: false,
          workoutSearchError: e.toString(),
        ),
      );
    }
  }

  void _onSearchWorkouts(
    SearchWorkoutsEvent event,
    Emitter<FitnessGoalsState> emit,
  ) async {
    final authState = _authBloc.state;
    if (authState is! AuthAuthenticated) {
      final currentState = _getCurrentStateWithCommonProps();
      emit(
        currentState.copyWith(
          isWorkoutSearchLoading: false,
          workoutSearchResults: [],
          workoutSearchError: 'Authentication required for search.',
        ),
      );
      return;
    }
    final token = authState.authModel.accessToken;

    final currentState = _getCurrentStateWithCommonProps();
    emit(
      currentState.copyWith(
        isWorkoutSearchLoading: true,
        workoutSearchResults: [], // Clear previous results when search starts
        workoutSearchError: null,
      ),
    );

    try {
      final results = await _repository.searchWorkouts(token, event.query);

      // Get latest state to avoid race conditions if other events occurred
      final latestState = _getCurrentStateWithCommonProps();
      emit(
        latestState.copyWith(
          isWorkoutSearchLoading: false,
          workoutSearchResults: results,
          workoutSearchError: null,
        ),
      );
    } catch (e) {
      final latestState = _getCurrentStateWithCommonProps();
      emit(
        latestState.copyWith(
          isWorkoutSearchLoading: false,
          workoutSearchResults: [],
          workoutSearchError: e.toString(),
        ),
      );
    }
  }

  void _onClearWorkoutSearchResults(
    ClearWorkoutSearchResultsEvent event,
    Emitter<FitnessGoalsState> emit,
  ) {
    final currentState = _getCurrentStateWithCommonProps();
    emit(
      currentState.copyWith(
        workoutSearchResults: [],
        isWorkoutSearchLoading: false,
        workoutSearchError: null,
      ),
    );
  }
}
