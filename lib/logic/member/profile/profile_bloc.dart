import 'package:equatable/equatable.dart';
import 'package:fit_and_fine/data/models/member_profile_model.dart';
import 'package:fit_and_fine/data/repositories/profile_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _profileRepository;

  ProfileBloc({required ProfileRepository profileRepository})
    : _profileRepository = profileRepository,
      super(ProfileInitial()) {
    on<FetchProfileData>(_onFetchProfileData);
  }

  Future<void> _onFetchProfileData(
    FetchProfileData event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      // This single call triggers the orchestration in the repository.
      // The BLoC remains simple and clean.
      final profileData = await _profileRepository.getFullUserProfile(
        'current_user_id',
      );
      emit(ProfileLoaded(profileData));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
