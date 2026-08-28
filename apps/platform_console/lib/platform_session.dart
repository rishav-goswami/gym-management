import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum PlatformSessionStatus { loading, signedOut, authorized, forbidden, error }

class PlatformSession extends ChangeNotifier {
  PlatformSession({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance {
    _subscription = _auth.authStateChanges().listen(_handleAuthChange);
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _subscription;

  PlatformSessionStatus status = PlatformSessionStatus.loading;
  User? user;
  String? message;

  Future<void> _handleAuthChange(User? nextUser) async {
    user = nextUser;
    message = null;
    if (nextUser == null) {
      status = PlatformSessionStatus.signedOut;
      notifyListeners();
      return;
    }
    status = PlatformSessionStatus.loading;
    notifyListeners();
    try {
      final token = await nextUser.getIdTokenResult(true);
      status = token.claims?['platformAdmin'] == true
          ? PlatformSessionStatus.authorized
          : PlatformSessionStatus.forbidden;
    } catch (error) {
      status = PlatformSessionStatus.error;
      message = 'Unable to verify platform access. $error';
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    status = PlatformSessionStatus.loading;
    message = null;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      status = PlatformSessionStatus.signedOut;
      message = error.message ?? 'Unable to sign in.';
      notifyListeners();
    }
  }

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
