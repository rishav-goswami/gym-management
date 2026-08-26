// ===============================================
// FILE: lib/data/models/progress_models.dart
// ===============================================
// These are the data models for the chart data.

import 'package:flutter/foundation.dart';

@immutable
class WeightEntry {
  final DateTime date;
  final double weight;

  const WeightEntry({required this.date, required this.weight});
}

@immutable
class StrengthEntry {
  final DateTime date;
  final String exerciseName;
  final double weight;

  const StrengthEntry({
    required this.date,
    required this.exerciseName,
    required this.weight,
  });
}
