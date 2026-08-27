import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management/firebase/domain/member_progress.dart';

void main() {
  test('workout logs produce exercise history, volume, and estimated max', () {
    final progress = MemberWorkoutProgress.fromLogs([
      (
        id: 'workout-1',
        data: <String, dynamic>{
          'title': 'Strength session',
          'completedAt': DateTime.utc(2026, 8, 20),
          'durationSeconds': 1800,
          'exercises': [
            {
              'exerciseId': 'squat',
              'name': 'Squat',
              'completedSets': 3,
              'repsPerSet': 8,
              'weightKg': 60,
            },
          ],
        },
      ),
      (
        id: 'workout-2',
        data: <String, dynamic>{
          'title': 'Strength session',
          'completedAt': DateTime.utc(2026, 8, 22),
          'durationSeconds': 2000,
          'exercises': [
            {
              'exerciseId': 'squat',
              'name': 'Squat',
              'completedSets': 4,
              'repsPerSet': 5,
              'weightKg': 70,
            },
          ],
        },
      ),
    ]);

    expect(progress.sessions, hasLength(2));
    expect(progress.exercises, hasLength(1));
    final squat = progress.exercises.single;
    expect(squat.bestWeightKg, 70);
    expect(squat.bestSessionVolumeKg, 1440);
    expect(squat.bestEstimatedOneRepMaxKg, closeTo(81.67, .01));
    expect(squat.entries.last.workoutId, 'workout-2');
  });

  test(
    'legacy target rep text remains usable and bodyweight uses rep records',
    () {
      final progress = MemberWorkoutProgress.fromLogs([
        (
          id: 'workout-1',
          data: <String, dynamic>{
            'completedAt': DateTime.utc(2026, 8, 20),
            'exercises': [
              {
                'exerciseId': 'pushup',
                'name': 'Push-up',
                'completedSets': 3,
                'targetReps': '8–15 reps',
              },
            ],
          },
        ),
      ]);

      final pushup = progress.exercises.single;
      expect(pushup.hasWeight, isFalse);
      expect(pushup.bestSetReps, 8);
      expect(pushup.bestSessionReps, 24);
    },
  );

  test('invalid and zero rep values are rejected', () {
    expect(parseFirstPositiveInteger('10-12 reps'), 10);
    expect(parseFirstPositiveInteger(6), 6);
    expect(parseFirstPositiveInteger('none'), isNull);
    expect(parseFirstPositiveInteger(0), isNull);
  });

  test(
    'variable strength sets and cardio efforts retain their real metrics',
    () {
      final progress = MemberWorkoutProgress.fromLogs([
        (
          id: 'mixed-workout',
          data: <String, dynamic>{
            'completedAt': DateTime.utc(2026, 8, 27),
            'exercises': [
              {
                'exerciseId': 'bench',
                'name': 'Bench press',
                'trackingType': 'strength',
                'completedSets': 3,
                'weightKg': 70,
                'sets': [
                  {'reps': 15, 'weightKg': 40},
                  {'reps': 15, 'weightKg': 50},
                  {'reps': 8, 'weightKg': 70},
                ],
              },
              {
                'exerciseId': 'treadmill',
                'name': 'Treadmill run',
                'trackingType': 'cardio',
                'completedSets': 1,
                'sets': [
                  {
                    'durationSeconds': 900,
                    'speedKph': 12,
                    'inclinePercent': 6,
                    'additionalLoadKg': 1,
                  },
                ],
              },
            ],
          },
        ),
      ]);

      final bench = progress.exercises.firstWhere(
        (item) => item.exerciseId == 'bench',
      );
      expect(bench.bestWeightKg, 70);
      expect(bench.bestSessionVolumeKg, 1910);
      expect(bench.bestEstimatedOneRepMaxKg, closeTo(88.67, .01));

      final treadmill = progress.exercises.firstWhere(
        (item) => item.exerciseId == 'treadmill',
      );
      expect(treadmill.isCardio, isTrue);
      expect(treadmill.bestDurationSeconds, 900);
      expect(treadmill.bestSpeedKph, 12);
      expect(treadmill.bestInclinePercent, 6);
    },
  );
}
