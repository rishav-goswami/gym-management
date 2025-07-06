import 'package:equatable/equatable.dart';
import 'package:fit_and_fine/data/models/member_profile_model.dart';
import 'package:fit_and_fine/data/repositories/profile_repository.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _profileRepository;
  final AuthBloc _authBloc;
  ProfileBloc({
    required ProfileRepository profileRepository,
    required AuthBloc authBloc,
  }) : _profileRepository = profileRepository,
       _authBloc = authBloc,
       super(ProfileInitial()) {
    on<FetchProfileData>(_onFetchProfileData);
  }

  Future<void> _onFetchProfileData(
    FetchProfileData event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    final authState = _authBloc.state;
    if (authState is! AuthAuthenticated) {
      // Optionally: _authBloc.add(AuthLogoutRequested());
      emit(const ProfileError('Not authenticated'));
      return;
    }
    try {
      final profileData = await _profileRepository.getFullUserProfile(
        authState.authModel.accessToken,
      );
      emit(ProfileLoaded(profileData));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
