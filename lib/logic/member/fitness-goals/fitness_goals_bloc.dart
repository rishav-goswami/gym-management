import 'package:equatable/equatable.dart';
import 'package:fit_and_fine/data/models/user_model.dart';
import 'package:fit_and_fine/data/repositories/fitness_goals_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'fitness_goals_event.dart';
part 'fitness_goals_state.dart';

class FitnessGoalsBloc extends Bloc<FitnessGoalsEvent, FitnessGoalsState> {
  final FitnessGoalsRepository _repository;

  FitnessGoalsBloc({required FitnessGoalsRepository repository})
    : _repository = repository,
      super(FitnessGoalsInitial()) {
    on<LoadFitnessGoals>(_onLoadFitnessGoals);
    on<UpdateFitnessGoals>(_onUpdateFitnessGoals);
  }

  Future<void> _onLoadFitnessGoals(
    LoadFitnessGoals event,
    Emitter<FitnessGoalsState> emit,
  ) async {
    emit(FitnessGoalsLoading());
    try {
      final user = await _repository.getFitnessGoals('current_user_id');
      emit(FitnessGoalsLoaded(user));
    } catch (e) {
      emit(FitnessGoalsError(e.toString()));
    }
  }

  Future<void> _onUpdateFitnessGoals(
    UpdateFitnessGoals event,
    Emitter<FitnessGoalsState> emit,
  ) async {
    // We can emit loading for the current state to show a spinner on the button
    if (state is FitnessGoalsLoaded) {
      final currentState = state as FitnessGoalsLoaded;
      emit(FitnessGoalsLoading()); // Show loading indicator

      try {
        final updates = {
          'healthGoals': event.primaryGoal,
          'workoutFrequency': event.workoutFrequency,
          'preferredWorkouts': event.preferredWorkouts.toList(),
        };
        final updatedUser = await _repository.updateFitnessGoals(
          'current_user_id',
          updates,
        );

        emit(FitnessGoalsUpdateSuccess()); // Emit success to show snackbar
        emit(FitnessGoalsLoaded(updatedUser)); // Then emit loaded with new data
      } catch (e) {
        emit(FitnessGoalsError(e.toString()));
        emit(currentState); // On error, revert to the previous loaded state
      }
    }
  }
}
