import 'package:equatable/equatable.dart';
import 'package:fit_and_fine/data/models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// You will need to create this repository.
// import 'package:fit_and_fine/data/repositories/profile_repository.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  // final ProfileRepository _profileRepository;

  ProfileBloc(/* {required ProfileRepository profileRepository} */)
    // : _profileRepository = profileRepository,
    : super(ProfileInitial()) {
    on<FetchUserProfile>(_onFetchUserProfile);
    on<UpdateUserProfile>(_onUpdateUserProfile);
  }

  Future<void> _onFetchUserProfile(
    FetchUserProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      // In a real app, call the repository:
      // final user = await _profileRepository.getUserProfile();
      // emit(ProfileLoaded(user));

      // Using mock data for now
      await Future.delayed(const Duration(seconds: 1));
      // This would come from your API
      const mockUser = Member(
        id: '123',
        name: 'Ethan Carter',
        email: 'ethan.carter@email.com',
        verified: false,
      );
      emit(const ProfileLoaded(mockUser));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onUpdateUserProfile(
    UpdateUserProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      // final updatedUser = await _profileRepository.updateUserProfile(event.updatedData);

      // In a real app, you would also need to update the AuthBloc's state
      // so the whole app has the new user info.

      // emit(ProfileLoaded(updatedUser));
      await Future.delayed(const Duration(seconds: 1));
      print('Data to update: ${event.name}');
      // This mock user would be the response from your API
      const mockUser = Member(
        id: '123',
        name: 'Ethan Carter Updated',
        email: 'ethan.carter@email.com',
        verified: false,
      );
      emit(const ProfileLoaded(mockUser));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
