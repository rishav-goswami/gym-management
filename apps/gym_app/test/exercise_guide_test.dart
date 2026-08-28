import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management/firebase/domain/exercise_guide.dart';

void main() {
  test('every exercise has usable guidance and pinned media', () {
    expect(exerciseGuides.length, greaterThanOrEqualTo(30));
    expect(
      exerciseGuides.map((exercise) => exercise.id).toSet(),
      hasLength(exerciseGuides.length),
    );
    for (final exercise in exerciseGuides) {
      expect(exercise.id, isNotEmpty);
      expect(exercise.instructions.length, greaterThanOrEqualTo(3));
      expect(exercise.imageUrls.length, 2);
      expect(exercise.storagePaths.length, 2);
      expect(
        exercise.storagePaths.every(
          (path) => path.startsWith('platform/exercise-media/v1/'),
        ),
        isTrue,
      );
      expect(
        exercise.imageUrls.every(
          (url) => url.contains('b0eed061e1c832b3ed815fbaa4b45b3cdc14df49'),
        ),
        isTrue,
      );
      expect(exercise.goals, isNotEmpty);
      expect(exercise.defaultSets, greaterThan(0));
      expect(exercise.restSeconds, greaterThan(0));
      expect(exercise.movementPattern, isNotEmpty);
      expect(exercise.coachingCues, isNotEmpty);
      expect(exercise.commonMistakes, isNotEmpty);
    }
  });

  test('every member goal provides a guided plan', () {
    for (final goal in TrainingGoal.values) {
      expect(exercisesForGoal(goal), isNotEmpty, reason: goal.label);
      expect(exercisesForGoal(goal, limit: 2).length, lessThanOrEqualTo(2));
    }
  });

  test('major movement families offer equipment and level variations', () {
    for (final id in [
      'Pushups',
      'Barbell_Full_Squat',
      'Pullups',
      'Plank',
      'Standing_Military_Press',
    ]) {
      final exercise = exerciseGuides.singleWhere((item) => item.id == id);
      expect(
        variationsFor(exercise),
        isNotEmpty,
        reason: '${exercise.name} should have an alternative',
      );
    }

    final squat = exerciseGuides.singleWhere(
      (exercise) => exercise.id == 'Barbell_Full_Squat',
    );
    expect(
      variationsFor(squat).map((exercise) => exercise.equipment).toSet().length,
      greaterThanOrEqualTo(3),
    );
  });
}
