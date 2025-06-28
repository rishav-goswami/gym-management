// lib/logic/member/profile/personal_info/personal_info_state.dart

part of 'personal_info_bloc.dart';

@immutable
abstract class PersonalInfoState extends Equatable {
  const PersonalInfoState();

  @override
  List<Object> get props => [];
}

class PersonalInfoInitial extends PersonalInfoState {}

class PersonalInfoLoading extends PersonalInfoState {}

class PersonalInfoLoaded extends PersonalInfoState {
  final Member user;

  const PersonalInfoLoaded(this.user);

  @override
  List<Object> get props => [user];
}

class PersonalInfoUpdateSuccess extends PersonalInfoState {
  final String message;
  const PersonalInfoUpdateSuccess(this.message);
  @override
  List<Object> get props => [message];
}

class PersonalInfoError extends PersonalInfoState {
  final String message;

  const PersonalInfoError(this.message);

  @override
  List<Object> get props => [message];
}
