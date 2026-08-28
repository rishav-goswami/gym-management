import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../logic/session_cubit.dart';

class ConsumerIntroScreen extends StatefulWidget {
  const ConsumerIntroScreen({super.key});

  @override
  State<ConsumerIntroScreen> createState() => _ConsumerIntroScreenState();
}

class _ConsumerIntroScreenState extends State<ConsumerIntroScreen> {
  static const _seenKey = 'consumer_intro_seen_v1';
  final _controller = PageController();
  int _page = 0;

  static const _benefits = [
    (
      icon: Icons.edit_calendar_outlined,
      title: 'Build workouts around your goals',
      body:
          'Create flexible routines for home or gym and change them as you grow.',
    ),
    (
      icon: Icons.monitor_heart_outlined,
      title: 'Log every set and understand your progress',
      body:
          'Track reps, weight, cardio, measurements and personal records in one place.',
    ),
    (
      icon: Icons.hub_outlined,
      title: 'Connect with your gym whenever you choose',
      body:
          'Add trainers, classes, attendance and membership services without giving up control of your fitness data.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _skipIfAlreadySeen();
  }

  Future<void> _skipIfAlreadySeen() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_seenKey) == true && mounted) context.go('/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branding = context.watch<SessionCubit>().state.platformBranding;
    final configured = branding['introduction'] as List? ?? const [];
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(onPressed: _finish, child: const Text('Skip')),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _benefits.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) {
                  final fallback = _benefits[index];
                  final configuredItem = index < configured.length
                      ? Map<String, dynamic>.from(configured[index] as Map)
                      : const <String, dynamic>{};
                  final title =
                      configuredItem['title'] as String? ?? fallback.title;
                  final body =
                      configuredItem['body'] as String? ?? fallback.body;
                  final imageUrl = configuredItem['imageUrl'] as String?;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 156,
                          height: 156,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          ),
                          child: imageUrl == null || imageUrl.isEmpty
                              ? Icon(
                                  fallback.icon,
                                  size: 76,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : ClipOval(
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      fallback.icon,
                                      size: 76,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 42),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Text(
                            body,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _benefits.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: index == _page ? 28 : 8,
                  height: 8,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: index == _page
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    child: Text(
                      _page == _benefits.length - 1
                          ? 'Get started'
                          : 'Continue',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _next() async {
    if (_page < _benefits.length - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_seenKey, true);
    if (mounted) context.go('/login');
  }
}
