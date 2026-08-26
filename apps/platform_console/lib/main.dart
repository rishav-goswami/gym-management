import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'platform_dashboard_screen.dart';
import 'platform_login_screen.dart';
import 'platform_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  const emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  await Firebase.initializeApp(
    options: useEmulators
        ? const FirebaseOptions(
            apiKey: 'demo-api-key',
            appId: '1:1234567890:web:demo-platform-console',
            messagingSenderId: '1234567890',
            projectId: 'demo-gym-dev',
            authDomain: 'demo-gym-dev.firebaseapp.com',
          )
        : DefaultFirebaseOptions.web,
  );
  if (useEmulators) {
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    FirebaseFunctions.instanceFor(
      region: 'asia-south1',
    ).useFunctionsEmulator(emulatorHost, 5001);
  }
  const appCheckSiteKey = String.fromEnvironment('FIREBASE_APPCHECK_SITE_KEY');
  if (!useEmulators && appCheckSiteKey.isNotEmpty) {
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(appCheckSiteKey),
    );
  }
  runApp(const PlatformConsoleApp());
}

class PlatformConsoleApp extends StatefulWidget {
  const PlatformConsoleApp({super.key});

  @override
  State<PlatformConsoleApp> createState() => _PlatformConsoleAppState();
}

class _PlatformConsoleAppState extends State<PlatformConsoleApp> {
  late final PlatformSession session;

  @override
  void initState() {
    super.initState();
    session = PlatformSession();
  }

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Gym Management Platform Console',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4338CA)),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF818CF8),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    themeMode: ThemeMode.system,
    home: ListenableBuilder(
      listenable: session,
      builder: (context, _) => switch (session.status) {
        PlatformSessionStatus.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        PlatformSessionStatus.signedOut => PlatformLoginScreen(
          onSignIn: session.signIn,
          message: session.message,
        ),
        PlatformSessionStatus.authorized => PlatformDashboardScreen(
          onSignOut: session.signOut,
        ),
        PlatformSessionStatus.forbidden => _AccessDeniedScreen(
          email: session.user?.email,
          onSignOut: session.signOut,
        ),
        PlatformSessionStatus.error => _AccessDeniedScreen(
          email: session.user?.email,
          message: session.message,
          onSignOut: session.signOut,
        ),
      },
    ),
  );
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen({
    required this.email,
    required this.onSignOut,
    this.message,
  });

  final String? email;
  final String? message;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.gpp_bad_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 20),
                Text(
                  'Platform access denied',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  message ??
                      '${email ?? 'This account'} does not have the trusted platformAdmin claim.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onSignOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
