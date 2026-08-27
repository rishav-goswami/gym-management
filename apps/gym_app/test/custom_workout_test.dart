import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management/firebase/domain/custom_workout.dart';

void main() {
  test('member routine preserves schedule and mixed movement types', () {
    final routine = MemberRoutine.fromMap('routine-a', {
      'name': 'Monday mixed training',
      'scheduledWeekdays': [1, 4],
      'status': 'active',
      'movements': [
        {
          'id': 'treadmill-a',
          'name': 'Treadmill run',
          'trackingType': 'cardio',
          'targetSets': 1,
        },
        {
          'id': 'bench-a',
          'exerciseId': 'Barbell_Bench_Press_-_Medium_Grip',
          'name': 'Barbell bench press',
          'trackingType': 'strength',
          'targetSets': 3,
        },
      ],
    });

    expect(routine.scheduledWeekdays, [1, 4]);
    expect(routine.movements, hasLength(2));
    expect(routine.movements.first.trackingType, MovementTrackingType.cardio);
    expect(routine.movements.last.targetSets, 3);
  });

  test('logged cardio supports incline, speed, time, and added load', () {
    const effort = LoggedMovementSet(
      durationSeconds: 900,
      speedKph: 12,
      inclinePercent: 6,
      additionalLoadKg: 1,
    );

    expect(effort.hasData, isTrue);
    expect(effort.toMap(1), {
      'setNumber': 1,
      'additionalLoadKg': 1.0,
      'durationSeconds': 900,
      'speedKph': 12.0,
      'inclinePercent': 6.0,
    });
  });
}
