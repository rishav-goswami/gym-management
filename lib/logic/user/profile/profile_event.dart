import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

class FetchProfile extends ProfileEvent {}
class UpdateProfile extends ProfileEvent {
  final Map<String, dynamic> update;
  const UpdateProfile(this.update);
  @override
  List<Object?> get props => [update];
}
