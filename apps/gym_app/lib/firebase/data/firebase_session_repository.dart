import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:gym_core/gym_core.dart';

import '../../core/config/app_environment.dart';

class FirebaseSessionRepository {
  FirebaseSessionRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : auth = auth ?? FirebaseAuth.instance,
       firestore = firestore ?? FirebaseFirestore.instance,
       functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  ConfirmationResult? _webConfirmation;
  AuthCredential? _pendingCredential;

  Stream<User?> get authChanges => auth.authStateChanges();
  Stream<Map<String, dynamic>> platformBrandingChanges() => firestore
      .doc('platform_public/app_branding')
      .snapshots()
      .map(
        (snapshot) => {
          ...?snapshot.data(),
          // Distinguishes a loaded-but-missing document from the initial state.
          // The router must not choose the legacy login route before this read.
          '_configurationLoaded': true,
        },
      );
  Stream<Map<String, dynamic>> gymChanges(String gymId) => firestore
      .doc('gyms/$gymId')
      .snapshots()
      .map((snapshot) => snapshot.data() ?? const {});
  Stream<String> get pushTokenChanges =>
      FirebaseMessaging.instance.onTokenRefresh;

  Future<UserCredential> signIn(String email, String password) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _linkPendingCredential(credential.user);
    if (!AppEnvironment.useEmulators) {
      await FirebaseAnalytics.instance.logLogin(loginMethod: 'password');
    }
    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..setCustomParameters({'prompt': 'select_account'});
    final credential = await _signInWithProvider(provider);
    await _ensureIdentityDocument(credential.user);
    if (!AppEnvironment.useEmulators) {
      await FirebaseAnalytics.instance.logLogin(loginMethod: 'google');
    }
    return credential;
  }

  Future<UserCredential> signInWithApple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    final credential = await _signInWithProvider(provider);
    await _ensureIdentityDocument(credential.user);
    if (!AppEnvironment.useEmulators) {
      await FirebaseAnalytics.instance.logLogin(loginMethod: 'apple');
    }
    return credential;
  }

  Future<UserCredential> createIdentity({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user!.updateDisplayName(name.trim());
    await credential.user!.sendEmailVerification();
    await firestore.doc('users/${credential.user!.uid}').set({
      'displayName': name.trim(),
      'email': email.trim().toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!AppEnvironment.useEmulators) {
      await FirebaseAnalytics.instance.logSignUp(signUpMethod: 'password');
    }
    return credential;
  }

  Future<void> ensureConsumerAccount() =>
      functions.httpsCallable('ensureConsumerAccount').call<void>();

  Future<Map<String, dynamic>> userAccount(String uid) async =>
      (await firestore.doc('users/$uid').get()).data() ?? const {};

  Future<void> completeConsumerOnboarding({
    required String displayName,
    required List<String> fitnessGoals,
    required String experienceLevel,
    required int workoutDaysPerWeek,
    required List<String> equipmentAccess,
    required bool ageConfirmed,
    required String termsVersion,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Sign in first.');
    final batch = firestore.batch();
    batch.set(firestore.doc('users/${user.uid}'), {
      'displayName': displayName.trim(),
      'ageConfirmedAt': ageConfirmed ? FieldValue.serverTimestamp() : null,
      'termsAcceptedAt': FieldValue.serverTimestamp(),
      'termsVersion': termsVersion,
      'onboardingCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(
      firestore.doc('users/${user.uid}/fitness_profile/current'),
      {
        'ownerUid': user.uid,
        'displayName': displayName.trim(),
        'fitnessGoals': fitnessGoals,
        'experienceLevel': experienceLevel,
        'workoutDaysPerWeek': workoutDaysPerWeek,
        'equipmentAccess': equipmentAccess,
        'onboardingCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    unawaited(
      functions
          .httpsCallable('trackFeatureUsage')
          .call<void>({
            'scopeType': 'personal',
            'audience': 'standalone',
            'featureId': 'onboarding',
          })
          .then<void>((_) {}, onError: (_) {}),
    );
  }

  Future<void> _ensureIdentityDocument(User? user) async {
    if (user == null) return;
    await firestore.doc('users/${user.uid}').set({
      'displayName': user.displayName,
      'email': user.email?.trim().toLowerCase(),
      'phone': user.phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<UserCredential> _signInWithProvider(AuthProvider provider) async {
    try {
      return kIsWeb
          ? await auth.signInWithPopup(provider)
          : await auth.signInWithProvider(provider);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'account-exists-with-different-credential' &&
          error.credential != null) {
        _pendingCredential = error.credential;
      }
      rethrow;
    }
  }

  Future<void> _linkPendingCredential(User? user) async {
    final pending = _pendingCredential;
    if (pending == null || user == null) return;
    await user.linkWithCredential(pending);
    _pendingCredential = null;
  }

  Future<void> signOut() async {
    final user = auth.currentUser;
    if (user != null) await removePushToken(user);
    await auth.signOut();
  }

  Future<void> sendEmailVerification() async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Sign in first.');
    await user.sendEmailVerification();
  }

  Future<bool> reloadEmailVerification() async {
    await auth.currentUser?.reload();
    await auth.currentUser?.getIdToken(true);
    return (auth.currentUser?.emailVerified ?? false) ||
        auth.currentUser?.phoneNumber != null;
  }

  Future<String?> sendPhoneCode(String phone) async {
    if (kIsWeb) {
      _webConfirmation = await auth.signInWithPhoneNumber(phone.trim());
      return 'web';
    }
    final completer = Completer<String?>();
    await auth.verifyPhoneNumber(
      phoneNumber: phone.trim(),
      verificationCompleted: (credential) async {
        await auth.signInWithCredential(credential);
        if (!completer.isCompleted) completer.complete(null);
      },
      verificationFailed: completer.completeError,
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
    );
    return completer.future;
  }

  Future<void> confirmPhoneCode(String verificationId, String code) async {
    if (kIsWeb) {
      await _webConfirmation!.confirm(code.trim());
      return;
    }
    await auth.signInWithCredential(
      PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code.trim(),
      ),
    );
  }

  Future<void> registerPushToken(User user) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(provisional: true);
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await messaging.getToken();
      if (token == null) return;
      await savePushToken(user.uid, token);
    } catch (_) {
      // Push setup is best-effort; it must never prevent a valid login.
    }
  }

  Future<void> savePushToken(String uid, String token) =>
      firestore.doc('users/$uid/device_tokens/$token').set({
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> removePushToken(User user) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) {
        await firestore.doc('users/${user.uid}/device_tokens/$token').delete();
      }
      await messaging.deleteToken();
    } catch (_) {
      // Logout must still succeed if notification cleanup is unavailable.
    }
  }

  Future<List<GymMembership>> membershipsFor(String uid) async {
    final snapshot = await firestore
        .collection('gym_memberships')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();
    return Future.wait(
      snapshot.docs.map((document) async {
        final data = document.data();
        final gymId = data['gymId'] as String;
        final gym = await firestore.doc('gyms/$gymId').get();
        return GymMembership(
          id: document.id,
          gymId: gymId,
          uid: uid,
          role: GymRole.fromJson(data['role'] as String? ?? 'member'),
          status: data['status'] as String? ?? 'inactive',
          permissions: Map<String, bool>.from(
            data['permissions'] as Map? ?? {},
          ),
        ).withGym(gym.data());
      }),
    );
  }

  Future<void> acceptInvitation({
    required String gymId,
    required String token,
  }) => functions.httpsCallable('acceptInvitation').call<void>({
    'gymId': gymId.trim(),
    'token': token.trim(),
  });

  Future<bool> leaveGymMembership(String gymId) async {
    final result = await functions.httpsCallable('leaveGymMembership').call({
      'gymId': gymId.trim(),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['cleanupPending'] == true;
  }

  Future<Map<String, dynamic>> exportMyData() async =>
      Map<String, dynamic>.from(
        (await functions.httpsCallable('exportMyData').call()).data as Map,
      );

  Future<void> requestAccountDeletion() =>
      functions.httpsCallable('requestAccountDeletion').call<void>();
}
