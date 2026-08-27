import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gym_core/gym_core.dart';

import '../../data/gym_media_repository.dart';
import '../../data/gym_repository.dart';

class MemberProfilePanel extends StatelessWidget {
  const MemberProfilePanel({required this.membership, super.key});

  final GymMembership membership;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: context.read<GymRepository>().memberProfile(
      membership.gymId,
      membership.uid,
    ),
    builder: (context, snapshot) {
      final profile = snapshot.data?.data() ?? const <String, dynamic>{};
      final complete = profile['onboardingCompletedAt'] != null;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Your profile',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Text(
            'These details improve general workout suggestions. A trainer should review medical or rehabilitation needs.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _ProfileAvatar(profile: profile),
                  const SizedBox(height: 12),
                  Text(
                    '${profile['displayName'] ?? 'Member'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    complete
                        ? 'Profile ready for recommendations'
                        : 'Complete onboarding to personalize training',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => _ProfileEditor(
                        membership: membership,
                        profile: profile,
                      ),
                    ),
                    icon: Icon(
                      complete ? Icons.edit_outlined : Icons.auto_awesome,
                    ),
                    label: Text(complete ? 'Edit profile' : 'Start onboarding'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ProfileSummary(profile: profile),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: const Text('Help improve the app'),
              subtitle: const Text(
                'Tell us which member feature is useful or needs work.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => _FeedbackDialog(membership: membership),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final path = profile['photoPath'] as String?;
    if (path == null) {
      return const CircleAvatar(
        radius: 44,
        child: Icon(Icons.person, size: 44),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: GymMediaRepository().readPrivatePhoto(path),
      builder: (context, snapshot) => CircleAvatar(
        radius: 44,
        backgroundImage: snapshot.data == null
            ? null
            : MemoryImage(snapshot.data!),
        child: snapshot.data == null
            ? const Icon(Icons.person, size: 44)
            : null,
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final goals = (profile['fitnessGoals'] as List? ?? const []).join(', ');
    final equipment = (profile['equipmentAccess'] as List? ?? const []).join(
      ', ',
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendation profile',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text('Goal: ${goals.isEmpty ? 'Not selected' : goals}'),
            Text('Experience: ${profile['experienceLevel'] ?? 'Not selected'}'),
            Text('Schedule: ${profile['workoutDaysPerWeek'] ?? '–'} days/week'),
            Text(
              'Equipment: ${equipment.isEmpty ? 'Not selected' : equipment}',
            ),
            if ((profile['limitations'] as String? ?? '').isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Limitations are saved for trainer context; automatic medical advice is not provided.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.membership, required this.profile});
  final GymMembership membership;
  final Map<String, dynamic> profile;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  static const goals = [
    'buildMuscle',
    'getStronger',
    'loseWeight',
    'improveFitness',
    'mobility',
  ];
  static const equipment = ['fullGym', 'dumbbells', 'bodyweight', 'homeGym'];
  late final name = TextEditingController(
    text: widget.profile['displayName'] as String? ?? '',
  );
  late final phone = TextEditingController(
    text: widget.profile['phone'] as String? ?? '',
  );
  late final height = TextEditingController(
    text: '${widget.profile['heightCm'] ?? ''}',
  );
  late final weight = TextEditingController(
    text: '${widget.profile['weightKg'] ?? ''}',
  );
  late final limitations = TextEditingController(
    text: widget.profile['limitations'] as String? ?? '',
  );
  late String experience =
      widget.profile['experienceLevel'] as String? ?? 'beginner';
  late int days = (widget.profile['workoutDaysPerWeek'] as num?)?.toInt() ?? 3;
  late Set<String> selectedGoals = Set<String>.from(
    widget.profile['fitnessGoals'] as List? ?? const ['improveFitness'],
  );
  late Set<String> selectedEquipment = Set<String>.from(
    widget.profile['equipmentAccess'] as List? ?? const ['fullGym'],
  );
  String? photoPath;
  bool saving = false;
  bool uploading = false;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    height.dispose();
    weight.dispose();
    limitations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Member onboarding'),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: uploading ? null : _upload,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(uploading ? 'Uploading…' : 'Choose profile image'),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: height,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height (cm)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: weight,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: experience,
              decoration: const InputDecoration(
                labelText: 'Training experience',
              ),
              items: const [
                DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                DropdownMenuItem(
                  value: 'intermediate',
                  child: Text('Intermediate'),
                ),
                DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
              ],
              onChanged: (value) => setState(() => experience = value!),
            ),
            const SizedBox(height: 16),
            Text(
              'Fitness goals',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: 8,
              children: goals
                  .map(
                    (goal) => FilterChip(
                      label: Text(_label(goal)),
                      selected: selectedGoals.contains(goal),
                      onSelected: (selected) => setState(
                        () => selected
                            ? selectedGoals.add(goal)
                            : selectedGoals.remove(goal),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'Available equipment',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: 8,
              children: equipment
                  .map(
                    (item) => FilterChip(
                      label: Text(_label(item)),
                      selected: selectedEquipment.contains(item),
                      onSelected: (selected) => setState(
                        () => selected
                            ? selectedEquipment.add(item)
                            : selectedEquipment.remove(item),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text('Workout days per week: $days'),
            Slider(
              value: days.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              label: '$days',
              onChanged: (value) => setState(() => days = value.round()),
            ),
            TextField(
              controller: limitations,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Injuries, limitations or trainer notes (optional)',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Saving…' : 'Save profile'),
      ),
    ],
  );

  Future<void> _upload() async {
    setState(() => uploading = true);
    try {
      photoPath = await GymMediaRepository().pickAndUploadProfilePhoto(
        gymId: widget.membership.gymId,
        uid: widget.membership.uid,
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _save() async {
    if (name.text.trim().length < 2 ||
        selectedGoals.isEmpty ||
        selectedEquipment.isEmpty) {
      return;
    }
    setState(() => saving = true);
    try {
      await GymRepository().updateMemberProfile(
        gymId: widget.membership.gymId,
        uid: widget.membership.uid,
        displayName: name.text,
        phone: phone.text,
        heightCm: double.tryParse(height.text),
        weightKg: double.tryParse(weight.text),
        experienceLevel: experience,
        fitnessGoals: selectedGoals.toList(),
        workoutDaysPerWeek: days,
        equipmentAccess: selectedEquipment.toList(),
        limitations: limitations.text,
        photoPath: photoPath,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save profile: $error')),
        );
      }
    }
  }

  String _label(String value) => value
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .trim();
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({required this.membership});
  final GymMembership membership;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final message = TextEditingController();
  String feature = 'training';
  int rating = 5;
  bool saving = false;

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Product feedback'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: feature,
            decoration: const InputDecoration(labelText: 'Feature'),
            items:
                const [
                      'training',
                      'progress',
                      'billing',
                      'attendance',
                      'classes',
                      'chat',
                      'profile',
                    ]
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: (value) => setState(() => feature = value!),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: [
              for (var value = 1; value <= 5; value++)
                ButtonSegment(value: value, label: Text('$value')),
            ],
            selected: {rating},
            onSelectionChanged: (value) => setState(() => rating = value.first),
          ),
          TextField(
            controller: message,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'What worked or needs improvement?',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _submit,
        child: Text(saving ? 'Sending…' : 'Send feedback'),
      ),
    ],
  );

  Future<void> _submit() async {
    if (message.text.trim().length < 3) return;
    setState(() => saving = true);
    try {
      await GymRepository().submitFeatureFeedback(
        gymId: widget.membership.gymId,
        featureId: feature,
        rating: rating,
        message: message.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => saving = false);
    }
  }
}
