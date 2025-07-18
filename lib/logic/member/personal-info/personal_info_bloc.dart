// lib/logic/member/profile/personal_info/personal_info_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:fit_and_fine/data/models/member_profile_model.dart';
import 'package:fit_and_fine/data/models/user_model.dart';
import 'package:fit_and_fine/data/repositories/personal_info_repository.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_event.dart';
import 'package:fit_and_fine/logic/auth/auth_state.dart';
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
    final authState = _authBloc.state;
    if (authState is! AuthAuthenticated) {
      // Optionally: _authBloc.add(AuthLogoutRequested());
      emit(const PersonalInfoError('Not authenticated'));
      return;
    }
    try {
      final memberPersonalInfo = await _repository.getPersonalInfo(
        authState.authModel.accessToken,
      );
      emit(PersonalInfoLoaded(memberPersonalInfo));
    } catch (e) {
      emit(PersonalInfoError(e.toString()));
    }
  }

  Future<void> _onUpdatePersonalInfo(
    UpdatePersonalInfo event,
    Emitter<PersonalInfoState> emit,
  ) async {
    emit(PersonalInfoLoading());
    final authState = _authBloc.state;
    if (authState is! AuthAuthenticated) {
      // Optionally: _authBloc.add(AuthLogoutRequested());
      emit(const PersonalInfoError('Not authenticated'));
      return;
    }
    try {
      final updates =
          {
            'name': event.name,
            'email': event.email,
            'phone': event.phone,
            'bio': event.bio,
            'avatarUrl': event.avatarUrl,
            'dob': event.dob?.toIso8601String(),
            'gender': event.gender?.name,
            'height': event.height,
            'weight': event.weight,
          }..removeWhere(
            (k, v) => v == null,
          ); // This trims the field with null values

      final updatedmemberPersonalInfo = await _repository.updatePersonalInfo(
        authState.authModel.accessToken,
        updates,
      );

      final memberCommanInfoForAuth = Member.fromJson({
        // 'id': updatedmemberPersonalInfo.id,
        'name': updatedmemberPersonalInfo.name,
        'email': updatedmemberPersonalInfo.email,
        'avatarUrl': updatedmemberPersonalInfo.avatarUrl,
        'phone': updatedmemberPersonalInfo.phone,
      });

      // Inform the global AuthBloc of the change
      _authBloc.add(AuthUserUpdated(memberCommanInfoForAuth));

      emit(const PersonalInfoUpdateSuccess('Profile updated successfully!'));
      emit(PersonalInfoLoaded(updatedmemberPersonalInfo));
    } catch (e) {
      emit(PersonalInfoError(e.toString()));
    }
  }
}
