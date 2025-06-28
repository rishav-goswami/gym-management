// ===============================================
// FILE: lib/logic/member/progress/progress_event.dart
// ===============================================

part of 'progress_bloc.dart';

@immutable
abstract class ProgressEvent extends Equatable {
  const ProgressEvent();

  @override
  List<Object> get props => [];
}

/// Event dispatched to fetch all data for the progress screen.
class FetchProgressData extends ProgressEvent {}
