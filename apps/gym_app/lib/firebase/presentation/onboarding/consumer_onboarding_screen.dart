import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../logic/session_cubit.dart';

class ConsumerOnboardingScreen extends StatefulWidget {
  const ConsumerOnboardingScreen({super.key, this.nextLocation});

  final String? nextLocation;

  @override
  State<ConsumerOnboardingScreen> createState() =>
      _ConsumerOnboardingScreenState();
}

class _ConsumerOnboardingScreenState extends State<ConsumerOnboardingScreen> {
  final _controller = PageController();
  late final TextEditingController _name;
  final _goals = <String>{};
  final _equipment = <String>{};
  String _experience = 'beginner';
  double _days = 3;
  int _page = 0;
  bool _ageConfirmed = false;
  bool _termsAccepted = false;
  bool _saving = false;

  static const _goalOptions = {
    'buildMuscle': 'Build muscle',
    'loseFat': 'Lose fat',
    'getStronger': 'Get stronger',
    'improveFitness': 'Improve fitness',
    'mobility': 'Move better',
  };
  static const _equipmentOptions = {
    'fullGym': 'Full gym',
    'dumbbells': 'Dumbbells',
    'bodyweight': 'Bodyweight',
    'bands': 'Resistance bands',
    'cardio': 'Cardio machines',
  };

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionCubit>().state;
    _name = TextEditingController(
      text:
          session.account['displayName'] as String? ??
          session.user?.displayName ??
          '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Set up My Fitness'),
        leading: _page == 0
            ? null
            : BackButton(
                onPressed: () => _controller.previousPage(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                ),
              ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _skipPreferences,
            child: const Text('Skip preferences'),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_page + 1) / 4),
          Expanded(
            child: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (value) => setState(() => _page = value),
              children: [
                _step(
                  title: 'First, a safe start',
                  body:
                      'Your fitness records are private. Connecting to a gym will never share them automatically.',
                  children: [
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'What should we call you?',
                      ),
                    ),
                    const SizedBox(height: 20),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _ageConfirmed,
                      onChanged: (value) =>
                          setState(() => _ageConfirmed = value == true),
                      title: const Text('I confirm that I am 18 or older'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _termsAccepted,
                      onChanged: (value) =>
                          setState(() => _termsAccepted = value == true),
                      title: const Text(
                        'I accept the Terms of Service and Privacy Policy',
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _openPolicy('termsUrl'),
                          child: const Text('Read terms'),
                        ),
                        TextButton(
                          onPressed: () => _openPolicy('privacyUrl'),
                          child: const Text('Read privacy policy'),
                        ),
                      ],
                    ),
                  ],
                ),
                _step(
                  title: 'What are you working toward?',
                  body:
                      'Choose as many as you like. You can change these later.',
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _goalOptions.entries
                          .map(
                            (entry) => FilterChip(
                              label: Text(entry.value),
                              selected: _goals.contains(entry.key),
                              onSelected: (selected) => setState(
                                () => selected
                                    ? _goals.add(entry.key)
                                    : _goals.remove(entry.key),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                _step(
                  title: 'Match training to your experience',
                  body: 'This helps us suggest an appropriate starting point.',
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'beginner',
                          label: Text('Beginner'),
                        ),
                        ButtonSegment(
                          value: 'intermediate',
                          label: Text('Regular'),
                        ),
                        ButtonSegment(
                          value: 'advanced',
                          label: Text('Advanced'),
                        ),
                      ],
                      selected: {_experience},
                      onSelectionChanged: (value) =>
                          setState(() => _experience = value.first),
                    ),
                    const SizedBox(height: 28),
                    Text('${_days.round()} workouts per week'),
                    Slider(
                      value: _days,
                      min: 1,
                      max: 7,
                      divisions: 6,
                      label: '${_days.round()}',
                      onChanged: (value) => setState(() => _days = value),
                    ),
                  ],
                ),
                _step(
                  title: 'What equipment can you use?',
                  body: 'We will keep exercise discovery relevant to you.',
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _equipmentOptions.entries
                          .map(
                            (entry) => FilterChip(
                              label: Text(entry.value),
                              selected: _equipment.contains(entry.key),
                              onSelected: (selected) => setState(
                                () => selected
                                    ? _equipment.add(entry.key)
                                    : _equipment.remove(entry.key),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _continue,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_page == 3 ? 'Enter My Fitness' : 'Continue'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _step({
    required String title,
    required String body,
    required List<Widget> children,
  }) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text(body, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 30),
            ...children,
          ],
        ),
      ),
    ],
  );

  Future<void> _continue() async {
    if (_page == 0) {
      if (_name.text.trim().isEmpty || !_ageConfirmed || !_termsAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter your name and accept both confirmations.'),
          ),
        );
        return;
      }
    }
    if (_page < 3) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
      return;
    }
    await _save();
  }

  Future<void> _skipPreferences() async {
    if (_page == 0 &&
        (_name.text.trim().isEmpty || !_ageConfirmed || !_termsAccepted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Age and policy acceptance are required to continue.'),
        ),
      );
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<SessionCubit>().completePersonalOnboarding(
        displayName: _name.text.trim(),
        fitnessGoals: _goals.toList(),
        experienceLevel: _experience,
        workoutDaysPerWeek: _days.round(),
        equipmentAccess: _equipment.toList(),
        ageConfirmed: _ageConfirmed,
      );
      if (mounted && widget.nextLocation != null) {
        context.go(widget.nextLocation!);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to save: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPolicy(String field) async {
    final branding = context.read<SessionCubit>().state.platformBranding;
    final rawUrl = branding[field] as String?;
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This policy link is not available yet.'),
          ),
        );
      }
    }
  }
}
