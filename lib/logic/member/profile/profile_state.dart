part of 'profile_bloc.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

/// The successful state, which now holds the single, composite MemberProfileData object.
class ProfileLoaded extends ProfileState {
  final MemberProfileData profileData;
  const ProfileLoaded(this.profileData);
  @override
  List<Object> get props => [profileData];
}

class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
  @override
  List<Object> get props => [message];
}
