import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management/firebase/domain/workout_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('workout draft survives local app-state recreation', () async {
    final startedAt = DateTime.utc(2026, 8, 27, 8);
    final draft = WorkoutDraft(
      gymId: 'gym-a',
      uid: 'member-a',
      goal: 'buildMuscle',
      exerciseIds: const ['squat', 'row'],
      completedSets: const [2, 1],
      weights: const ['40', '25'],
      startedAt: startedAt,
    );

    await WorkoutDraftStore.save(draft);
    final restored = await WorkoutDraftStore.load('member-a', 'gym-a');

    expect(restored, isNotNull);
    expect(restored!.completedSets, [2, 1]);
    expect(restored.weights, ['40', '25']);
    expect(restored.startedAt, startedAt);
    expect(
      restored.matches(
        expectedGymId: 'gym-a',
        expectedUid: 'member-a',
        expectedGoal: 'buildMuscle',
        expectedExerciseIds: const ['squat', 'row'],
      ),
      isTrue,
    );
  });

  test('workout drafts are isolated by member and gym', () async {
    await WorkoutDraftStore.save(
      WorkoutDraft(
        gymId: 'gym-a',
        uid: 'member-a',
        goal: 'mobility',
        exerciseIds: const ['stretch'],
        completedSets: const [1],
        weights: const [''],
        startedAt: DateTime.utc(2026),
      ),
    );

    expect(await WorkoutDraftStore.load('member-b', 'gym-a'), isNull);
    expect(await WorkoutDraftStore.load('member-a', 'gym-b'), isNull);
    await WorkoutDraftStore.clear('member-a', 'gym-a');
    expect(await WorkoutDraftStore.load('member-a', 'gym-a'), isNull);
  });
}
