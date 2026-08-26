import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_core/gym_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/firebase_session_repository.dart';

enum SessionStatus { initializing, signedOut, selectingContext, ready, failure }

class SessionState extends Equatable {
  const SessionState({
    this.status = SessionStatus.initializing,
    this.user,
    this.memberships = const [],
    this.activeMembership,
    this.message,
  });

  final SessionStatus status;
  final User? user;
  final List<GymMembership> memberships;
  final GymMembership? activeMembership;
  final String? message;

  @override
  List<Object?> get props => [
    status,
    user?.uid,
    memberships,
    activeMembership,
    message,
  ];
}

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._repository) : super(const SessionState()) {
    _subscription = _repository.authChanges.listen(_onAuthChanged);
  }

  static const _selectedMembershipKey = 'selected_firebase_membership';
  final FirebaseSessionRepository _repository;
  late final StreamSubscription<User?> _subscription;

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      emit(const SessionState(status: SessionStatus.signedOut));
      return;
    }
    emit(SessionState(status: SessionStatus.initializing, user: user));
    try {
      final results = await Future.wait<dynamic>([
        _repository.membershipsFor(user.uid),
        SharedPreferences.getInstance(),
      ]);
      final memberships = results[0] as List<GymMembership>;
      final preferences = results[1] as SharedPreferences;
      final selectedId = preferences.getString(_selectedMembershipKey);
      unawaited(_repository.registerPushToken(user));
      GymMembership? selected;
      for (final membership in memberships) {
        if (membership.id == selectedId) selected = membership;
      }
      if (memberships.length == 1) selected ??= memberships.first;
      emit(
        SessionState(
          status: selected != null
              ? SessionStatus.ready
              : SessionStatus.selectingContext,
          user: user,
          memberships: memberships,
          activeMembership: selected,
        ),
      );
    } catch (error) {
      emit(
        SessionState(
          status: SessionStatus.failure,
          user: user,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> signIn(String email, String password) async {
    emit(const SessionState(status: SessionStatus.initializing));
    try {
      await _repository.signIn(email, password);
    } on FirebaseAuthException catch (error) {
      emit(
        SessionState(
          status: SessionStatus.signedOut,
          message: error.message ?? 'Unable to sign in.',
        ),
      );
    }
  }

  Future<void> register(String name, String email, String password) async {
    emit(const SessionState(status: SessionStatus.initializing));
    try {
      await _repository.createIdentity(
        name: name,
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      emit(
        SessionState(
          status: SessionStatus.signedOut,
          message: error.message ?? 'Unable to create account.',
        ),
      );
    }
  }

  Future<void> selectMembership(GymMembership membership) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_selectedMembershipKey, membership.id);
    emit(
      SessionState(
        status: SessionStatus.ready,
        user: state.user,
        memberships: state.memberships,
        activeMembership: membership,
      ),
    );
  }

  Future<void> chooseAnotherContext() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_selectedMembershipKey);
    emit(
      SessionState(
        status: SessionStatus.selectingContext,
        user: state.user,
        memberships: state.memberships,
      ),
    );
  }

  Future<void> refreshContexts() async =>
      _onAuthChanged(_repository.auth.currentUser);

  Future<void> signOut() => _repository.signOut();

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
