// ===============================================
// FILE: lib/logic/member/progress/progress_state.dart
// ===============================================

part of 'progress_bloc.dart';

@immutable
abstract class ProgressState extends Equatable {
  const ProgressState();

  @override
  List<Object> get props => [];
}

/// The initial state before any data is fetched.
class ProgressInitial extends ProgressState {}

/// The state when data is being fetched from the API.
class ProgressLoading extends ProgressState {}

/// The state when data has been successfully loaded.
/// It holds all the data needed for the charts.
class ProgressLoaded extends ProgressState {
  final List<WeightEntry> weightHistory;
  final List<StrengthEntry> strengthHistory;

  const ProgressLoaded({
    required this.weightHistory,
    required this.strengthHistory,
  });

  @override
  List<Object> get props => [weightHistory, strengthHistory];
}

/// The state when an error occurs while fetching data.
class ProgressError extends ProgressState {
  final String message;

  const ProgressError(this.message);

  @override
  List<Object> get props => [message];
}
