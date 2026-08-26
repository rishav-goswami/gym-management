class MembershipQuote {
  const MembershipQuote({
    required this.amountMinor,
    required this.startsAt,
    required this.endsAt,
  });

  final int amountMinor;
  final DateTime startsAt;
  final DateTime endsAt;

  static MembershipQuote create({
    required String amount,
    required DateTime startsAt,
    required int durationDays,
  }) {
    final parsed = double.tryParse(amount.trim());
    if (parsed == null || parsed < 0) {
      throw const FormatException('Invalid amount');
    }
    if (durationDays < 1 || durationDays > 3660) {
      throw const FormatException('Invalid membership duration');
    }
    return MembershipQuote(
      amountMinor: (parsed * 100).round(),
      startsAt: startsAt,
      endsAt: startsAt.add(Duration(days: durationDays)),
    );
  }
}

class WorkoutSetTarget {
  const WorkoutSetTarget({
    required this.sets,
    required this.reps,
    this.weightKg,
  });
  final int sets;
  final int reps;
  final double? weightKg;

  /// Accepts compact trainer input such as `3x12` or `5x5@60`.
  static WorkoutSetTarget parse(String value) {
    final match = RegExp(
      r'^(\d{1,2})x(\d{1,3})(?:@(\d+(?:\.\d+)?))?$',
    ).firstMatch(value.trim().toLowerCase());
    if (match == null) {
      throw const FormatException('Use sets x reps, for example 3x12@20');
    }
    final sets = int.parse(match.group(1)!);
    final reps = int.parse(match.group(2)!);
    final weight = match.group(3) == null
        ? null
        : double.parse(match.group(3)!);
    if (sets == 0 || reps == 0) {
      throw const FormatException('Sets and reps must be positive');
    }
    return WorkoutSetTarget(sets: sets, reps: reps, weightKg: weight);
  }
}

double goalProgress({
  required double start,
  required double current,
  required double target,
}) {
  if (start == target) return current == target ? 1 : 0;
  final progress = (current - start) / (target - start);
  return progress.clamp(0, 1).toDouble();
}
