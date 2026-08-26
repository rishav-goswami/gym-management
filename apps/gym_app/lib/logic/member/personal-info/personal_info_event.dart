// lib/logic/member/profile/personal_info/personal_info_event.dart

part of 'personal_info_bloc.dart';

@immutable
abstract class PersonalInfoEvent extends Equatable {
  const PersonalInfoEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to load the initial user data for the form.
class LoadPersonalInfo extends PersonalInfoEvent {}

/// Dispatched when the user taps the 'Save' button with all the updated data.
class UpdatePersonalInfo extends PersonalInfoEvent {
  final String name;
  final String email;
  final double? phone;
  final String? bio;
  final String? avatarUrl;
  final DateTime? dob;
  final Gender? gender;
  final double? height;
  final double? weight;

  const UpdatePersonalInfo({
    required this.name,
    required this.email,
    this.phone,
    this.bio,
    this.avatarUrl,
    this.dob,
    this.gender,
    this.height,
    this.weight,
  });

  @override
  List<Object?> get props => [
    name,
    email,
    phone,
    bio,
    avatarUrl,
    dob,
    gender,
    height,
    weight,
  ];
}
