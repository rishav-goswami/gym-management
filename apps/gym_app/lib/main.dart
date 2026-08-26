import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/firebase/firebase_bootstrap.dart';
import 'core/theme/theme.dart';
import 'firebase/data/firebase_session_repository.dart';
import 'firebase/data/gym_media_repository.dart';
import 'firebase/data/gym_repository.dart';
import 'firebase/logic/session_cubit.dart';
import 'routes/firebase_app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  runApp(const GymApp());
}

class GymApp extends StatefulWidget {
  const GymApp({super.key});

  @override
  State<GymApp> createState() => _GymAppState();
}

class _GymAppState extends State<GymApp> {
  late final FirebaseSessionRepository _sessionRepository;
  late final GymRepository _gymRepository;
  late final GymMediaRepository _mediaRepository;
  late final SessionCubit _sessionCubit;
  late final router = createFirebaseRouter(_sessionCubit);

  @override
  void initState() {
    super.initState();
    _sessionRepository = FirebaseSessionRepository();
    _gymRepository = GymRepository();
    _mediaRepository = GymMediaRepository();
    _sessionCubit = SessionCubit(_sessionRepository);
  }

  @override
  void dispose() {
    _sessionCubit.close();
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider.value(value: _sessionRepository),
      RepositoryProvider.value(value: _gymRepository),
      RepositoryProvider.value(value: _mediaRepository),
    ],
    child: BlocProvider.value(
      value: _sessionCubit,
      child: BlocBuilder<SessionCubit, SessionState>(
        builder: (context, session) {
          final seed = _brandColor(session.activeMembership?.primaryColor);
          return MaterialApp.router(
            title: session.activeMembership?.gymName ?? 'Gym Management',
            debugShowCheckedModeBanner: false,
            theme: lightTheme.copyWith(
              colorScheme: ColorScheme.fromSeed(seedColor: seed),
            ),
            darkTheme: darkTheme.copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: seed,
                brightness: Brightness.dark,
              ),
            ),
            themeMode: ThemeMode.system,
            routerConfig: router,
          );
        },
      ),
    ),
  );

  Color _brandColor(String? hex) {
    final value = hex?.replaceFirst('#', '');
    if (value == null || value.length != 6) return const Color(0xFF2563EB);
    return Color(int.parse('FF$value', radix: 16));
  }
}
