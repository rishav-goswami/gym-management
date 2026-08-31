import 'package:flutter/material.dart';

/// The sharing categories offered to a member for a given gym, in display
/// order. Keys match the `SharingCategory` values the `updateGymSharing`
/// Cloud Function and its projection pipeline expect.
const kGymSharingCategories = [
  'profile',
  'goals',
  'workoutSummaries',
  'measurements',
  'progress',
];

String sharingCategoryLabel(String key) => switch (key) {
  'profile' => 'Profile basics',
  'goals' => 'Fitness goals',
  'workoutSummaries' => 'Workout summaries',
  'measurements' => 'Body measurements',
  'progress' => 'Progress records and photos',
  _ => key,
};

String sharingCategoryDescription(String key) => switch (key) {
  'profile' => 'Basic identity and fitness preferences for member support.',
  'goals' => 'Your active goals and targets, not day-to-day measurements.',
  'workoutSummaries' =>
    'Completion and adherence summaries, not private notes.',
  'measurements' => 'Selected body measurements and their changes over time.',
  'progress' => 'Personal records and progress entries covered by this grant.',
  _ => '',
};

/// Shows the "share with your gym" category checklist and returns the
/// chosen category map if the user saved, or `null` if they cancelled.
Future<Map<String, bool>?> showGymSharingDialog(
  BuildContext context, {
  required String gymName,
  required Map<String, bool> current,
  String introText =
      'Sharing helps authorized staff or trainers support you. Your '
      'membership features work even when every option is off.',
  bool showDescriptions = true,
  String saveLabel = 'Save',
  String cancelLabel = 'Cancel',
}) {
  final values = {
    for (final key in kGymSharingCategories) key: current[key] ?? false,
  };
  return showDialog<Map<String, bool>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Share with $gymName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(introText),
              const SizedBox(height: 12),
              ...values.keys.map(
                (key) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: values[key]!,
                  title: Text(sharingCategoryLabel(key)),
                  subtitle: showDescriptions
                      ? Text(sharingCategoryDescription(key))
                      : null,
                  onChanged: (value) =>
                      setDialogState(() => values[key] = value),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, values),
            child: Text(saveLabel),
          ),
        ],
      ),
    ),
  );
}
