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
  final PersonalInfo personalInfo;

  const PersonalInfoLoaded(this.personalInfo);

  @override
  List<Object> get props => [personalInfo];
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
