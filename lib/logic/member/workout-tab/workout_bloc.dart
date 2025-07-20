import 'package:equatable/equatable.dart';
import 'package:fit_and_fine/data/models/workout_models.dart';
import 'package:fit_and_fine/data/repositories/workouts_repository.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'workout_event.dart';
part 'workout_state.dart';

class WorkoutBloc extends Bloc<WorkoutEvent, WorkoutState> {
  final WorkoutRepository _workoutRepository;
  final AuthBloc _authBloc; // We need this to get the token

  WorkoutBloc({
    required WorkoutRepository workoutRepository,
    required AuthBloc authBloc,
  }) : _workoutRepository = workoutRepository,
       _authBloc = authBloc,
       super(WorkoutInitial()) {
    on<FetchWorkoutData>(_onFetchWorkoutData);
  }

  Future<void> _onFetchWorkoutData(
    FetchWorkoutData event,
    Emitter<WorkoutState> emit,
  ) async {
    final authState = _authBloc.state;
    if (authState is! AuthAuthenticated) {
      emit(const WorkoutError('User not authenticated.'));
      return;
    }

    emit(WorkoutLoading());
    try {
      final token = authState.authModel.accessToken;
      final (workoutPlan, exerciseLibrary) = await _workoutRepository
          .getWorkoutTabData(token);

      emit(
        WorkoutLoaded(
          workoutPlan: workoutPlan,
          exerciseLibrary: exerciseLibrary,
        ),
      );
    } catch (e) {
      emit(WorkoutError(e.toString()));
    }
  }
}
