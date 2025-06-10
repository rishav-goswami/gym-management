import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthWrapper extends StatelessWidget {
  final Widget child;
  final String baseUrl;
  const AuthWrapper({required this.child, required this.baseUrl, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(baseUrl: baseUrl),
      child: child,
    );
  }
}
