import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_core/gym_core.dart';

import '../data/firebase_session_repository.dart';

enum SessionStatus { initializing, signedOut, selectingContext, ready, failure }

GymMembership? preferredOperationalMembership(
  Iterable<GymMembership> memberships,
) {
  const priority = <GymRole, int>{
    GymRole.owner: 0,
    GymRole.manager: 1,
    GymRole.trainer: 2,
    GymRole.receptionist: 3,
    GymRole.accountant: 4,
  };
  final operational =
      memberships
          .where((membership) => priority.containsKey(membership.role))
          .toList()
        ..sort((left, right) {
          final byRole = priority[left.role]!.compareTo(priority[right.role]!);
          return byRole != 0
              ? byRole
              : left.gymName.toLowerCase().compareTo(
                  right.gymName.toLowerCase(),
                );
        });
  return operational.firstOrNull;
}

GymMembership? preferredMemberMembership(Iterable<GymMembership> memberships) {
  final members =
      memberships
          .where((membership) => membership.role == GymRole.member)
          .toList()
        ..sort(
          (left, right) =>
              left.gymName.toLowerCase().compareTo(right.gymName.toLowerCase()),
        );
  return members.firstOrNull;
}

bool personalSpacesEnabledFor(Map<String, dynamic> branding) {
  final features = Map<String, dynamic>.from(
    branding['consumerFeatures'] as Map? ?? const {},
  );
  return features['personalSpacesV1'] == true;
}

GymMembership? preferredInitialMembership(
  Iterable<GymMembership> memberships, {
  required bool personalSpacesEnabled,
}) => personalSpacesEnabled ? preferredMemberMembership(memberships) : null;

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
    return personalSpacesEnabledFor(platformBranding);
  }

  bool get platformBrandingLoaded =>
      platformBranding['_configurationLoaded'] == true;
  GymMembership? get primaryOperationalMembership =>
      preferredOperationalMembership(memberships);
  GymMembership? get primaryMemberMembership =>
      preferredMemberMembership(memberships);
  GymMembership? get memberAppMembership =>
      activeMembership?.role == GymRole.member
      ? activeMembership
      : primaryMemberMembership;

  FitnessScope? get activeFitnessScope => user == null
      ? null
      : activeMembership == null || activeMembership!.role == GymRole.member
      ? FitnessScope.personal(user!.uid)
      : FitnessScope.gym(activeMembership!);
  AppSpace? get activeSpace => user == null
      ? null
      : activeMembership == null || activeMembership!.role == GymRole.member
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
      _onBrandingChanged,
    );
  }

  final FirebaseSessionRepository _repository;
  late final StreamSubscription<User?> _subscription;
  late final StreamSubscription<Map<String, dynamic>> _brandingSubscription;
  StreamSubscription<String>? _pushTokenSubscription;
  StreamSubscription<Map<String, dynamic>>? _gymSubscription;

  void _onBrandingChanged(Map<String, dynamic> branding) {
    final personalSpacesEnabled = personalSpacesEnabledFor(branding);
    final currentMembership = state.activeMembership;
    final nextMembership =
        currentMembership?.role == GymRole.member && !personalSpacesEnabled
        ? null
        : currentMembership ??
              preferredInitialMembership(
                state.memberships,
                personalSpacesEnabled: personalSpacesEnabled,
              );
    emit(
      SessionState(
        status: state.status,
        user: state.user,
        memberships: state.memberships,
        activeMembership: nextMembership,
        account: state.account,
        platformBranding: branding,
        message: state.message,
      ),
    );
    if (nextMembership == null && currentMembership != null) {
      final subscription = _gymSubscription;
      _gymSubscription = null;
      if (subscription != null) unawaited(subscription.cancel());
    }
    if (nextMembership != null && nextMembership.id != currentMembership?.id) {
      unawaited(_watchGym(nextMembership));
    }
  }

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
        activeMembership: preferredInitialMembership(
          memberships,
          personalSpacesEnabled: state.personalSpacesEnabled,
        ),
        account: account,
        platformBranding: state.platformBranding,
      );
      emit(nextState);
      if (nextState.activeMembership != null) {
        await _watchGym(nextState.activeMembership!);
      }
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
    final memberMembership = preferredInitialMembership(
      state.memberships,
      personalSpacesEnabled: state.personalSpacesEnabled,
    );
    emit(
      SessionState(
        status: SessionStatus.ready,
        user: state.user,
        memberships: state.memberships,
        activeMembership: memberMembership,
        account: state.account,
        platformBranding: state.platformBranding,
      ),
    );
    if (memberMembership != null) await _watchGym(memberMembership);
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
