import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/firebase/firebase_bootstrap.dart';
import 'core/theme/theme.dart';
import 'firebase/data/firebase_session_repository.dart';
import 'firebase/data/gym_media_repository.dart';
import 'firebase/data/gym_repository.dart';
import 'firebase/data/support_repository.dart';
import 'firebase/logic/session_cubit.dart';
import 'routes/firebase_app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) usePathUrlStrategy();
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
  late final SupportRepository _supportRepository;
  late final SessionCubit _sessionCubit;
  late final router = createFirebaseRouter(_sessionCubit);
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<SessionState>? _sessionSubscription;
  RemoteMessage? _pendingMessage;

  @override
  void initState() {
    super.initState();
    _sessionRepository = FirebaseSessionRepository();
    _gymRepository = GymRepository();
    _mediaRepository = GymMediaRepository();
    _supportRepository = SupportRepository();
    _sessionCubit = SessionCubit(_sessionRepository);
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _queueNotification,
    );
    _sessionSubscription = _sessionCubit.stream.listen((state) {
      if (state.status == SessionStatus.ready && _pendingMessage != null) {
        final message = _pendingMessage!;
        _pendingMessage = null;
        _openNotification(message);
      }
    });
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _queueNotification(message);
    });
  }

  @override
  void dispose() {
    _messageOpenedSubscription?.cancel();
    _sessionSubscription?.cancel();
    _sessionCubit.close();
    router.dispose();
    super.dispose();
  }

  void _queueNotification(RemoteMessage message) {
    if (message.data['type'] != 'support') return;
    if (_sessionCubit.state.status != SessionStatus.ready) {
      _pendingMessage = message;
      return;
    }
    _openNotification(message);
  }

  void _openNotification(RemoteMessage message) {
    final threadId = message.data['threadId'];
    if (threadId == null || threadId.isEmpty) return;
    router.go(
      Uri(
        path: '/support',
        queryParameters: {
          'scope': message.data['scopeType'] ?? 'platform',
          'threadId': threadId,
          if (message.data['gymId']?.isNotEmpty == true)
            'gymId': message.data['gymId'],
          'title': message.notification?.title ?? 'Support conversation',
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider.value(value: _sessionRepository),
      RepositoryProvider.value(value: _gymRepository),
      RepositoryProvider.value(value: _mediaRepository),
      RepositoryProvider.value(value: _supportRepository),
    ],
    child: BlocProvider.value(
      value: _sessionCubit,
      child: BlocBuilder<SessionCubit, SessionState>(
        builder: (context, session) {
          final platform = session.platformBranding;
          final seed = _brandColor(
            session.activeMembership?.primaryColor ??
                platform['primaryColor'] as String?,
          );
          final secondary = _brandColor(
            session.activeMembership?.secondaryColor ??
                platform['secondaryColor'] as String?,
            fallback: const Color(0xFF0F172A),
          );
          final accent = _brandColor(
            session.activeMembership?.accentColor ??
                platform['accentColor'] as String?,
            fallback: const Color(0xFFF97316),
          );
          final lightScheme = ColorScheme.fromSeed(
            seedColor: seed,
          ).copyWith(secondary: secondary, tertiary: accent);
          final darkScheme = ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          ).copyWith(secondary: secondary, tertiary: accent);
          return MaterialApp.router(
            title:
                session.activeMembership?.gymName ??
                platform['name'] as String? ??
                'Gym Management',
            debugShowCheckedModeBanner: false,
            theme: lightTheme.copyWith(colorScheme: lightScheme),
            darkTheme: darkTheme.copyWith(colorScheme: darkScheme),
            themeMode: ThemeMode.system,
            routerConfig: router,
          );
        },
      ),
    ),
  );

  Color _brandColor(String? hex, {Color fallback = const Color(0xFF2563EB)}) {
    final value = hex?.replaceFirst('#', '');
    if (value == null || value.length != 6) return fallback;
    return Color(int.tryParse('FF$value', radix: 16) ?? fallback.toARGB32());
  }
}
