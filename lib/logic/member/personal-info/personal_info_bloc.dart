// lib/logic/member/profile/personal_info/personal_info_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:fit_and_fine/data/models/user_model.dart';
import 'package:fit_and_fine/data/repositories/personal_info_repository.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'personal_info_event.dart';
part 'personal_info_state.dart';

class PersonalInfoBloc extends Bloc<PersonalInfoEvent, PersonalInfoState> {
  final PersonalInfoRepository _repository;
  final AuthBloc _authBloc;

  PersonalInfoBloc({
    required PersonalInfoRepository repository,
    required AuthBloc authBloc,
  }) : _repository = repository,
       _authBloc = authBloc,
       super(PersonalInfoInitial()) {
    on<LoadPersonalInfo>(_onLoadPersonalInfo);
    on<UpdatePersonalInfo>(_onUpdatePersonalInfo);
  }

  Future<void> _onLoadPersonalInfo(
    LoadPersonalInfo event,
    Emitter<PersonalInfoState> emit,
  ) async {
    emit(PersonalInfoLoading());
    try {
      final user = await _repository.getPersonalInfo('current_user_id');
      emit(PersonalInfoLoaded(user));
    } catch (e) {
      emit(PersonalInfoError(e.toString()));
    }
  }

  Future<void> _onUpdatePersonalInfo(
    UpdatePersonalInfo event,
    Emitter<PersonalInfoState> emit,
  ) async {
    emit(PersonalInfoLoading());
    try {
      // Create a map from the event to send to the repository
      final updates = {
        'name': event.name,
        'email': event.email,
        'phone': event.phone,
        'bio': event.bio,
        'avatarUrl': event.avatarUrl,
        'dob': event.dob?.toIso8601String(),
        'gender': event.gender?.name,
        'height': event.height,
        'weight': event.weight,
      };

      final updatedUser = await _repository.updatePersonalInfo(
        'current_user_id',
        updates,
      );

      // Inform the global AuthBloc of the change
      _authBloc.add(AuthUserUpdated(updatedUser));

      emit(const PersonalInfoUpdateSuccess('Profile updated successfully!'));
      emit(PersonalInfoLoaded(updatedUser));
    } catch (e) {
      emit(PersonalInfoError(e.toString()));
    }
  }
}
