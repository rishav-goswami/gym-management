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

  Stream<User?> get authChanges => auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (!AppEnvironment.useEmulators) {
      await FirebaseAnalytics.instance.logLogin(loginMethod: 'password');
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

  Future<void> signOut() => auth.signOut();

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
      await firestore.doc('users/${user.uid}/device_tokens/$token').set({
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Push setup is best-effort; it must never prevent a valid login.
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

  Future<Map<String, dynamic>> exportMyData() async =>
      Map<String, dynamic>.from(
        (await functions.httpsCallable('exportMyData').call()).data as Map,
      );

  Future<void> requestAccountDeletion() =>
      functions.httpsCallable('requestAccountDeletion').call<void>();
}
