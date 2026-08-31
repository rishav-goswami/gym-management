import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WorkoutDraft {
  const WorkoutDraft({
    required this.gymId,
    required this.uid,
    required this.goal,
    required this.exerciseIds,
    required this.completedSets,
    required this.weights,
    required this.repsPerSet,
    required this.startedAt,
    this.exerciseIndex = 0,
  });

  final String gymId;
  final String uid;
  final String goal;
  final List<String> exerciseIds;
  final List<int> completedSets;
  final List<String> weights;
  final List<String> repsPerSet;
  final DateTime startedAt;
  final int exerciseIndex;

  bool matches({
    required String expectedGymId,
    required String expectedUid,
    required String expectedGoal,
    required List<String> expectedExerciseIds,
  }) =>
      gymId == expectedGymId &&
      uid == expectedUid &&
      goal == expectedGoal &&
      _sameValues(exerciseIds, expectedExerciseIds) &&
      completedSets.length == exerciseIds.length &&
      weights.length == exerciseIds.length &&
      repsPerSet.length == exerciseIds.length;

  Map<String, dynamic> toJson() => {
    'schemaVersion': 3,
    'gymId': gymId,
    'uid': uid,
    'goal': goal,
    'exerciseIds': exerciseIds,
    'completedSets': completedSets,
    'weights': weights,
    'repsPerSet': repsPerSet,
    'startedAt': startedAt.toIso8601String(),
    'exerciseIndex': exerciseIndex,
  };

  static WorkoutDraft? fromJson(Map<String, dynamic> json) {
    try {
      final schemaVersion = json['schemaVersion'];
      if (schemaVersion != 1 && schemaVersion != 2 && schemaVersion != 3) {
        return null;
      }
      final exerciseIds = List<String>.from(json['exerciseIds'] as List);
      return WorkoutDraft(
        gymId: json['gymId'] as String,
        uid: json['uid'] as String,
        goal: json['goal'] as String,
        exerciseIds: exerciseIds,
        completedSets: List<int>.from(json['completedSets'] as List),
        weights: List<String>.from(json['weights'] as List),
        repsPerSet: schemaVersion == 2 || schemaVersion == 3
            ? List<String>.from(json['repsPerSet'] as List)
            : List.filled(exerciseIds.length, ''),
        startedAt: DateTime.parse(json['startedAt'] as String),
        exerciseIndex: schemaVersion == 3
            ? (json['exerciseIndex'] as num?)?.toInt() ?? 0
            : 0,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _sameValues(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

class WorkoutDraftStore {
  const WorkoutDraftStore._();

  static String _key(String uid, String gymId) => 'workout_draft::$uid::$gymId';

  static Future<WorkoutDraft?> load(String uid, String gymId) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key(uid, gymId));
    if (encoded == null) return null;
    try {
      return WorkoutDraft.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } catch (_) {
      await preferences.remove(_key(uid, gymId));
      return null;
    }
  }

  static Future<void> save(WorkoutDraft draft) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(draft.uid, draft.gymId),
      jsonEncode(draft.toJson()),
    );
  }

  static Future<void> clear(String uid, String gymId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(uid, gymId));
  }
}
