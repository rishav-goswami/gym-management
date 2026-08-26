import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'core/config/app_environment.dart';

/// Runtime Firebase options supplied with `--dart-define` in CI and releases.
/// Demo defaults are intentionally suitable only for the local Emulator Suite.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform => FirebaseOptions(
    apiKey: AppEnvironment.apiKey,
    appId: AppEnvironment.appId,
    messagingSenderId: AppEnvironment.messagingSenderId,
    projectId: AppEnvironment.projectId,
    storageBucket: AppEnvironment.storageBucket,
    iosBundleId: kIsWeb ? null : 'com.example.fitAndFine',
  );
}
