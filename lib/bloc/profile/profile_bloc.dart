import 'dart:convert';
import 'package:bloc/bloc.dart';

import 'package:http/http.dart' as http;

import '../../models/user_profile.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final String baseUrl;
  String? _token;
  ProfileBloc({required this.baseUrl}) : super(ProfileInitial()) {
    on<FetchProfile>(_onFetchProfile);
    on<UpdateProfile>(_onUpdateProfile);
    on<SetProfileToken>(_onSetProfileToken);
  }

  void setToken(String? token) {
    add(SetProfileToken(token));
  }

  Future<void> _onSetProfileToken(SetProfileToken event, Emitter<ProfileState> emit) async {
    _token = event.token;
  }

  Future<void> _onFetchProfile(
    FetchProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/me'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] != null) {
        emit(ProfileLoaded(UserProfile.fromMap(data['data'])));
      } else {
        emit(ProfileError(data['message'] ?? 'Failed to fetch profile'));
      }
    } catch (e) {
      emit(ProfileError('Failed to fetch profile: $e'));
    }
  }

  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user/me'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(event.update),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] != null) {
        emit(ProfileLoaded(UserProfile.fromMap(data['data'])));
      } else {
        emit(ProfileError(data['message'] ?? 'Failed to update profile'));
      }
    } catch (e) {
      emit(ProfileError('Failed to update profile: $e'));
    }
  }
}

class SetProfileToken extends ProfileEvent {
  final String? token;
  const SetProfileToken(this.token);
  @override
  List<Object?> get props => [token];
}
