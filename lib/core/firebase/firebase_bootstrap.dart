import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../config/app_environment.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: AppEnvironment.useEmulators || AppEnvironment.hasFirebaseOverride
          ? AppEnvironment.firebaseOptions
          : DefaultFirebaseOptions.currentPlatform,
    );

    if (AppEnvironment.useEmulators) {
      final host = AppEnvironment.emulatorHost;
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).useFunctionsEmulator(host, 5001);
      await _setRemoteConfigDefaults();
    } else {
      await _activateAppCheck();
      await _activateObservabilityAndConfig();
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  static Future<void> _activateAppCheck() async {
    if (kIsWeb && AppEnvironment.webAppCheckSiteKey.isEmpty) return;
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      providerWeb: kIsWeb
          ? ReCaptchaV3Provider(AppEnvironment.webAppCheckSiteKey)
          : null,
    );
  }

  static Future<void> _activateObservabilityAndConfig() async {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
    final remoteConfig = FirebaseRemoteConfig.instance;
    await _setRemoteConfigDefaults();
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 5)
            : const Duration(hours: 6),
      ),
    );
    try {
      await remoteConfig.fetchAndActivate();
    } catch (error, stack) {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: false,
      );
    }
  }

  static Future<void> _setRemoteConfigDefaults() =>
      FirebaseRemoteConfig.instance.setDefaults(const {
        'chat_enabled': true,
        'attendance_qr_enabled': true,
        'progress_photos_enabled': true,
        'maintenance_message': '',
      });
}
