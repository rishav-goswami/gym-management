part of 'profile_bloc.dart';

@immutable
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object> get props => [];
}

/// Dispatched to fetch the user's full, up-to-date profile.
class FetchUserProfile extends ProfileEvent {}

/// Dispatched when the EditProfileScreen is opened to load user data.
class LoadUserProfile extends ProfileEvent {}

/// Dispatched from the EditProfileScreen to save changes.
class UpdateUserProfile extends ProfileEvent {
  final String name;
  final String bio;
  final String avatarUrl;
  // Add other fields as needed

  const UpdateUserProfile({
    required this.name,
    required this.bio,
    required this.avatarUrl,
  });

  @override
  List<Object> get props => [name, bio, avatarUrl];
}
