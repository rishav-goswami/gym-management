// ===============================================
// FILE: lib/logic/member/progress/progress_bloc.dart
// ===============================================

import 'package:equatable/equatable.dart';
import 'package:fit_and_fine/data/models/progress_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Import your repository here when you create it
// import 'package:fit_and_fine/data/repositories/progress_repository.dart';

part 'progress_event.dart';
part 'progress_state.dart';

class ProgressBloc extends Bloc<ProgressEvent, ProgressState> {
  // final ProgressRepository _progressRepository;

  ProgressBloc(/* {required ProgressRepository progressRepository} */)
    // : _progressRepository = progressRepository,
    : super(ProgressInitial()) {
    on<FetchProgressData>(_onFetchProgressData);
  }

  Future<void> _onFetchProgressData(
    FetchProgressData event,
    Emitter<ProgressState> emit,
  ) async {
    emit(ProgressLoading());
    try {
      // In a real app, you would call your repository here:
      // final weightData = await _progressRepository.getWeightHistory();
      // final strengthData = await _progressRepository.getStrengthHistory();

      // For now, we will use mock data to simulate the API call.
      await Future.delayed(const Duration(milliseconds: 500));

      final weightData = [
        WeightEntry(date: DateTime(2024, 1), weight: 155),
        WeightEntry(date: DateTime(2024, 2), weight: 152),
        WeightEntry(date: DateTime(2024, 3), weight: 153),
        WeightEntry(date: DateTime(2024, 4), weight: 148),
        WeightEntry(date: DateTime(2024, 5), weight: 150),
        WeightEntry(date: DateTime(2024, 6), weight: 154),
      ];

      final strengthData = [
        StrengthEntry(
          date: DateTime(2024, 1),
          exerciseName: 'Bench Press',
          weight: 160,
        ),
        StrengthEntry(
          date: DateTime(2024, 2),
          exerciseName: 'Bench Press',
          weight: 165,
        ),
        StrengthEntry(
          date: DateTime(2024, 3),
          exerciseName: 'Bench Press',
          weight: 170,
        ),
        StrengthEntry(
          date: DateTime(2024, 4),
          exerciseName: 'Bench Press',
          weight: 175,
        ),
        StrengthEntry(
          date: DateTime(2024, 5),
          exerciseName: 'Bench Press',
          weight: 178,
        ),
        StrengthEntry(
          date: DateTime(2024, 6),
          exerciseName: 'Bench Press',
          weight: 180,
        ),
      ];

      emit(
        ProgressLoaded(
          weightHistory: weightData,
          strengthHistory: strengthData,
        ),
      );
    } catch (e) {
      emit(ProgressError(e.toString()));
    }
  }
}
