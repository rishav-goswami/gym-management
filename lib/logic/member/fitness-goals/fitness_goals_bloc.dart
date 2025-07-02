
import 'package:equatable/equatable.dart';
// import 'package:fit_and_fine/data/models/user_model.dart';
import 'package:fit_and_fine/data/models/fitness_goals_model.dart';
import 'package:fit_and_fine/data/repositories/fitness_goals_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_state.dart';

part 'fitness_goals_event.dart';
part 'fitness_goals_state.dart';

class FitnessGoalsBloc extends Bloc<FitnessGoalsEvent, FitnessGoalsState> {
  final FitnessGoalsRepository _repository;
  final AuthBloc _authBloc;

  FitnessGoalsBloc({required FitnessGoalsRepository repository, required AuthBloc authBloc})
      : _repository = repository,
        _authBloc = authBloc,
        super(FitnessGoalsInitial()) {
    on<LoadFitnessGoals>(_onLoadFitnessGoals);
    on<UpdateFitnessGoals>(_onUpdateFitnessGoals);
  }

  Future<void> _onLoadFitnessGoals(
    LoadFitnessGoals event,
    Emitter<FitnessGoalsState> emit,
  ) async {
    emit(FitnessGoalsLoading());
    final authState = _authBloc.state;
    if (authState is! AuthAuthenticated) {
      emit(FitnessGoalsError('Not authenticated'));
      return;
    }
    try {
      final goals = await _repository.getFitnessGoals(authState.authModel.accessToken);
      emit(FitnessGoalsLoaded(goals));
    } catch (e) {
      emit(FitnessGoalsError(e.toString()));
    }
  }

  Future<void> _onUpdateFitnessGoals(
    UpdateFitnessGoals event,
    Emitter<FitnessGoalsState> emit,
  ) async {
    if (state is FitnessGoalsLoaded) {
      final currentState = state as FitnessGoalsLoaded;
      emit(FitnessGoalsLoading());

      final authState = _authBloc.state;
      if (authState is! AuthAuthenticated) {
        emit(FitnessGoalsError('Not authenticated'));
        emit(currentState);
        return;
      }

      try {
        final updates = {
          'healthGoals': event.primaryGoal,
          'workoutFrequency': event.workoutFrequency,
          'preferredWorkouts': event.preferredWorkouts.toList(),
        }..removeWhere((k, v) => v == null);
        final updatedGoals = await _repository.updateFitnessGoals(
          authState.authModel.accessToken,
          updates,
        );

        emit(FitnessGoalsUpdateSuccess());
        emit(FitnessGoalsLoaded(updatedGoals));
      } catch (e) {
        emit(FitnessGoalsError(e.toString()));
        emit(currentState);
      }
    }
  }
}
