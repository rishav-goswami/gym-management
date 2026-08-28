import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_core/gym_core.dart';

import '../data/firebase_session_repository.dart';

enum SessionStatus { initializing, signedOut, selectingContext, ready, failure }

class SessionState extends Equatable {
  const SessionState({
    this.status = SessionStatus.initializing,
    this.user,
    this.memberships = const [],
    this.activeMembership,
    this.account = const {},
    this.platformBranding = const {},
    this.message,
  });

  final SessionStatus status;
  final User? user;
  final List<GymMembership> memberships;
  final GymMembership? activeMembership;
  final Map<String, dynamic> account;
  final Map<String, dynamic> platformBranding;
  final String? message;

  bool get needsPersonalOnboarding =>
      user != null && account['onboardingCompletedAt'] == null;
  bool get personalSpacesEnabled {
    final features = Map<String, dynamic>.from(
      platformBranding['consumerFeatures'] as Map? ?? const {},
    );
    return features['personalSpacesV1'] == true;
  }

  bool get platformBrandingLoaded =>
      platformBranding['_configurationLoaded'] == true;

  FitnessScope? get activeFitnessScope => user == null
      ? null
      : activeMembership == null
      ? FitnessScope.personal(user!.uid)
      : FitnessScope.gym(activeMembership!);
  AppSpace? get activeSpace => user == null
      ? null
      : activeMembership == null
      ? PersonalSpace(uid: user!.uid)
      : GymSpace(membership: activeMembership!);

  @override
  List<Object?> get props => [
    status,
    user?.uid,
    memberships,
    activeMembership,
    account,
    platformBranding,
    message,
  ];
}

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._repository) : super(const SessionState()) {
    _subscription = _repository.authChanges.listen(_onAuthChanged);
    _brandingSubscription = _repository.platformBrandingChanges().listen(
      (branding) => emit(
        SessionState(
          status: state.status,
          user: state.user,
          memberships: state.memberships,
          activeMembership: state.activeMembership,
          account: state.account,
          platformBranding: branding,
          message: state.message,
        ),
      ),
    );
  }

  final FirebaseSessionRepository _repository;
  late final StreamSubscription<User?> _subscription;
  late final StreamSubscription<Map<String, dynamic>> _brandingSubscription;
  StreamSubscription<String>? _pushTokenSubscription;
  StreamSubscription<Map<String, dynamic>>? _gymSubscription;

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      await _gymSubscription?.cancel();
      _gymSubscription = null;
      await _pushTokenSubscription?.cancel();
      _pushTokenSubscription = null;
      emit(
        SessionState(
          status: SessionStatus.signedOut,
          platformBranding: state.platformBranding,
        ),
      );
      return;
    }
    emit(
      SessionState(
        status: SessionStatus.initializing,
        user: user,
        platformBranding: state.platformBranding,
      ),
    );
    try {
      await _repository.ensureConsumerAccount();
      final results = await Future.wait<dynamic>([
        _repository.membershipsFor(user.uid),
        _repository.userAccount(user.uid),
      ]);
      final memberships = results[0] as List<GymMembership>;
      final account = results[1] as Map<String, dynamic>;
      unawaited(_repository.registerPushToken(user));
      await _pushTokenSubscription?.cancel();
      _pushTokenSubscription = _repository.pushTokenChanges.listen(
        (token) => _repository.savePushToken(user.uid, token),
      );
      final nextState = SessionState(
        status: SessionStatus.ready,
        user: user,
        memberships: memberships,
        account: account,
        platformBranding: state.platformBranding,
      );
      emit(nextState);
    } catch (error) {
      emit(
        SessionState(
          status: SessionStatus.failure,
          user: user,
          platformBranding: state.platformBranding,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> signIn(String email, String password) async {
    emit(
      SessionState(
        status: SessionStatus.initializing,
        platformBranding: state.platformBranding,
      ),
    );
    try {
      await _repository.signIn(email, password);
    } on FirebaseAuthException catch (error) {
      emit(
        SessionState(
          status: SessionStatus.signedOut,
          platformBranding: state.platformBranding,
          message: error.message ?? 'Unable to sign in.',
        ),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    emit(
      SessionState(
        status: SessionStatus.initializing,
        platformBranding: state.platformBranding,
      ),
    );
    try {
      await _repository.signInWithGoogle();
    } on FirebaseAuthException catch (error) {
      emit(
        SessionState(
          status: SessionStatus.signedOut,
          platformBranding: state.platformBranding,
          message: error.code == 'account-exists-with-different-credential'
              ? 'This email already uses another sign-in method. Sign in that way first, then link this provider in Settings.'
              : error.message ?? 'Unable to sign in with Google.',
        ),
      );
    }
  }

  Future<void> signInWithApple() async {
    emit(
      SessionState(
        status: SessionStatus.initializing,
        platformBranding: state.platformBranding,
      ),
    );
    try {
      await _repository.signInWithApple();
    } on FirebaseAuthException catch (error) {
      emit(
        SessionState(
          status: SessionStatus.signedOut,
          platformBranding: state.platformBranding,
          message: error.code == 'account-exists-with-different-credential'
              ? 'This email already uses another sign-in method. Sign in that way first, then link this provider in Settings.'
              : error.message ?? 'Unable to sign in with Apple.',
        ),
      );
    }
  }

  Future<void> register(String name, String email, String password) async {
    emit(
      SessionState(
        status: SessionStatus.initializing,
        platformBranding: state.platformBranding,
      ),
    );
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
          platformBranding: state.platformBranding,
          message: error.message ?? 'Unable to create account.',
        ),
      );
    }
  }

  Future<void> selectMembership(GymMembership membership) async {
    emit(
      SessionState(
        status: SessionStatus.ready,
        user: state.user,
        memberships: state.memberships,
        activeMembership: membership,
        account: state.account,
        platformBranding: state.platformBranding,
      ),
    );
    await _watchGym(membership);
  }

  Future<void> choosePersonalSpace() async {
    await _gymSubscription?.cancel();
    _gymSubscription = null;
    emit(
      SessionState(
        status: SessionStatus.ready,
        user: state.user,
        memberships: state.memberships,
        account: state.account,
        platformBranding: state.platformBranding,
      ),
    );
  }

  Future<void> chooseAnotherContext() async {
    await _gymSubscription?.cancel();
    _gymSubscription = null;
    emit(
      SessionState(
        status: SessionStatus.selectingContext,
        user: state.user,
        memberships: state.memberships,
        account: state.account,
        platformBranding: state.platformBranding,
      ),
    );
  }

  Future<void> refreshContexts() async =>
      _onAuthChanged(_repository.auth.currentUser);

  Future<void> completePersonalOnboarding({
    required String displayName,
    required List<String> fitnessGoals,
    required String experienceLevel,
    required int workoutDaysPerWeek,
    required List<String> equipmentAccess,
    required bool ageConfirmed,
  }) async {
    await _repository.completeConsumerOnboarding(
      displayName: displayName,
      fitnessGoals: fitnessGoals,
      experienceLevel: experienceLevel,
      workoutDaysPerWeek: workoutDaysPerWeek,
      equipmentAccess: equipmentAccess,
      ageConfirmed: ageConfirmed,
      termsVersion: '2026-08-28',
    );
    await refreshContexts();
  }

  Future<void> signOut() => _repository.signOut();

  Future<void> _watchGym(GymMembership membership) async {
    await _gymSubscription?.cancel();
    _gymSubscription = _repository.gymChanges(membership.gymId).listen((gym) {
      final current = state.activeMembership;
      if (current == null || current.gymId != membership.gymId) return;
      final updated = current.withGym(gym);
      emit(
        SessionState(
          status: state.status,
          user: state.user,
          memberships: state.memberships
              .map((item) => item.id == updated.id ? updated : item)
              .toList(),
          activeMembership: updated,
          account: state.account,
          platformBranding: state.platformBranding,
          message: state.message,
        ),
      );
    });
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _brandingSubscription.cancel();
    await _pushTokenSubscription?.cancel();
    await _gymSubscription?.cancel();
    return super.close();
  }
}
