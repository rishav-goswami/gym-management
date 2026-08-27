import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management/firebase/domain/exercise_guide.dart';

void main() {
  test('every exercise has usable guidance and pinned media', () {
    expect(exerciseGuides, isNotEmpty);
    for (final exercise in exerciseGuides) {
      expect(exercise.id, isNotEmpty);
      expect(exercise.instructions.length, greaterThanOrEqualTo(3));
      expect(exercise.imageUrls.length, 2);
      expect(
        exercise.imageUrls.every(
          (url) => url.contains('b0eed061e1c832b3ed815fbaa4b45b3cdc14df49'),
        ),
        isTrue,
      );
      expect(exercise.goals, isNotEmpty);
      expect(exercise.defaultSets, greaterThan(0));
      expect(exercise.restSeconds, greaterThan(0));
    }
  });

  test('every member goal provides a guided plan', () {
    for (final goal in TrainingGoal.values) {
      expect(exercisesForGoal(goal), isNotEmpty, reason: goal.label);
      expect(exercisesForGoal(goal, limit: 2).length, lessThanOrEqualTo(2));
    }
  });
}
