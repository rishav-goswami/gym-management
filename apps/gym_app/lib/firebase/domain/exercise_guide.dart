enum TrainingGoal {
  buildMuscle('Build muscle', 'Hypertrophy-focused strength work'),
  getStronger('Get stronger', 'Practice the main movement patterns'),
  loseWeight('Lose weight', 'Higher-tempo full-body sessions'),
  improveFitness('Improve fitness', 'Balanced strength and conditioning'),
  mobility('Move better', 'Mobility and recovery work');

  const TrainingGoal(this.label, this.description);

  final String label;
  final String description;
}

class ExerciseGuide {
  const ExerciseGuide({
    required this.id,
    required this.name,
    required this.level,
    required this.equipment,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.instructions,
    required this.imagePaths,
    required this.goals,
    required this.defaultSets,
    required this.defaultReps,
    required this.restSeconds,
  });

  static const _sourceRoot =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/'
      'b0eed061e1c832b3ed815fbaa4b45b3cdc14df49/exercises';

  final String id;
  final String name;
  final String level;
  final String equipment;
  final String primaryMuscle;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final List<String> imagePaths;
  final Set<TrainingGoal> goals;
  final int defaultSets;
  final String defaultReps;
  final int restSeconds;

  List<String> get imageUrls =>
      imagePaths.map((path) => '$_sourceRoot/$path').toList(growable: false);
}

const exerciseGuides = <ExerciseGuide>[
  ExerciseGuide(
    id: 'Pushups',
    name: 'Push-ups',
    level: 'Beginner',
    equipment: 'Bodyweight',
    primaryMuscle: 'Chest',
    secondaryMuscles: ['Shoulders', 'Triceps'],
    instructions: [
      'Start in a strong plank with hands slightly wider than your shoulders.',
      'Lower under control until your chest is close to the floor.',
      'Press the floor away while keeping your hips and shoulders moving together.',
    ],
    imagePaths: ['Pushups/0.jpg', 'Pushups/1.jpg'],
    goals: {
      TrainingGoal.buildMuscle,
      TrainingGoal.loseWeight,
      TrainingGoal.improveFitness,
    },
    defaultSets: 3,
    defaultReps: '8–15 reps',
    restSeconds: 60,
  ),
  ExerciseGuide(
    id: 'Barbell_Bench_Press_-_Medium_Grip',
    name: 'Barbell bench press',
    level: 'Beginner',
    equipment: 'Barbell and bench',
    primaryMuscle: 'Chest',
    secondaryMuscles: ['Shoulders', 'Triceps'],
    instructions: [
      'Lie on the bench with feet planted and use a secure medium-width grip.',
      'Lower the bar slowly toward the middle of your chest.',
      'Press upward with control. Use a spotter or safety arms for challenging loads.',
    ],
    imagePaths: [
      'Barbell_Bench_Press_-_Medium_Grip/0.jpg',
      'Barbell_Bench_Press_-_Medium_Grip/1.jpg',
    ],
    goals: {TrainingGoal.buildMuscle, TrainingGoal.getStronger},
    defaultSets: 3,
    defaultReps: '6–10 reps',
    restSeconds: 90,
  ),
  ExerciseGuide(
    id: 'Barbell_Full_Squat',
    name: 'Barbell squat',
    level: 'Intermediate',
    equipment: 'Barbell and squat rack',
    primaryMuscle: 'Quadriceps',
    secondaryMuscles: ['Glutes', 'Hamstrings', 'Calves'],
    instructions: [
      'Set the rack and safety arms before loading the bar.',
      'Brace your trunk, sit the hips down and back, and keep your feet planted.',
      'Stand by driving through the whole foot while keeping the bar controlled.',
    ],
    imagePaths: ['Barbell_Full_Squat/0.jpg', 'Barbell_Full_Squat/1.jpg'],
    goals: {
      TrainingGoal.buildMuscle,
      TrainingGoal.getStronger,
      TrainingGoal.improveFitness,
    },
    defaultSets: 3,
    defaultReps: '6–10 reps',
    restSeconds: 120,
  ),
  ExerciseGuide(
    id: 'Bent_Over_Barbell_Row',
    name: 'Bent-over barbell row',
    level: 'Beginner',
    equipment: 'Barbell',
    primaryMuscle: 'Back',
    secondaryMuscles: ['Lats', 'Biceps', 'Shoulders'],
    instructions: [
      'Hinge at the hips with soft knees and keep your back braced.',
      'Pull the bar toward your torso while keeping your elbows controlled.',
      'Pause briefly, then lower the bar without changing torso position.',
    ],
    imagePaths: ['Bent_Over_Barbell_Row/0.jpg', 'Bent_Over_Barbell_Row/1.jpg'],
    goals: {TrainingGoal.buildMuscle, TrainingGoal.getStronger},
    defaultSets: 3,
    defaultReps: '8–12 reps',
    restSeconds: 90,
  ),
  ExerciseGuide(
    id: 'Dumbbell_Lunges',
    name: 'Dumbbell lunges',
    level: 'Beginner',
    equipment: 'Dumbbells',
    primaryMuscle: 'Quadriceps',
    secondaryMuscles: ['Glutes', 'Hamstrings', 'Calves'],
    instructions: [
      'Stand tall with a dumbbell at each side.',
      'Step forward and lower with control while maintaining balance.',
      'Push through the front foot to return, then repeat on the other side.',
    ],
    imagePaths: ['Dumbbell_Lunges/0.jpg', 'Dumbbell_Lunges/1.jpg'],
    goals: {
      TrainingGoal.buildMuscle,
      TrainingGoal.loseWeight,
      TrainingGoal.improveFitness,
    },
    defaultSets: 3,
    defaultReps: '8–12 / side',
    restSeconds: 60,
  ),
  ExerciseGuide(
    id: 'Pullups',
    name: 'Pull-ups',
    level: 'Beginner',
    equipment: 'Pull-up bar',
    primaryMuscle: 'Lats',
    secondaryMuscles: ['Biceps', 'Back'],
    instructions: [
      'Hang from the bar with a grip you can control.',
      'Pull your shoulders down and bring your upper chest toward the bar.',
      'Lower slowly to full arm extension without dropping into the bottom.',
    ],
    imagePaths: ['Pullups/0.jpg', 'Pullups/1.jpg'],
    goals: {TrainingGoal.buildMuscle, TrainingGoal.getStronger},
    defaultSets: 3,
    defaultReps: '5–10 reps',
    restSeconds: 90,
  ),
  ExerciseGuide(
    id: 'Plank',
    name: 'Plank',
    level: 'Beginner',
    equipment: 'Bodyweight',
    primaryMuscle: 'Core',
    secondaryMuscles: [],
    instructions: [
      'Support yourself on your forearms and toes with elbows below shoulders.',
      'Keep a straight line from head to heels and breathe normally.',
      'End the set when you can no longer hold the position cleanly.',
    ],
    imagePaths: ['Plank/0.jpg', 'Plank/1.jpg'],
    goals: {
      TrainingGoal.loseWeight,
      TrainingGoal.improveFitness,
      TrainingGoal.mobility,
    },
    defaultSets: 3,
    defaultReps: '20–45 sec',
    restSeconds: 45,
  ),
  ExerciseGuide(
    id: 'Mountain_Climbers',
    name: 'Mountain climbers',
    level: 'Beginner',
    equipment: 'Bodyweight',
    primaryMuscle: 'Full body',
    secondaryMuscles: ['Quadriceps', 'Chest', 'Shoulders'],
    instructions: [
      'Begin in a stable push-up position.',
      'Bring one knee toward the hip while keeping your hands planted.',
      'Alternate legs at a pace that lets you maintain a steady trunk.',
    ],
    imagePaths: ['Mountain_Climbers/0.jpg', 'Mountain_Climbers/1.jpg'],
    goals: {TrainingGoal.loseWeight, TrainingGoal.improveFitness},
    defaultSets: 3,
    defaultReps: '20–30 sec',
    restSeconds: 45,
  ),
  ExerciseGuide(
    id: 'Romanian_Deadlift',
    name: 'Romanian deadlift',
    level: 'Intermediate',
    equipment: 'Barbell',
    primaryMuscle: 'Hamstrings',
    secondaryMuscles: ['Glutes', 'Lower back'],
    instructions: [
      'Hold the bar close to your legs with knees slightly bent.',
      'Push your hips back while keeping your trunk braced and the bar controlled.',
      'Stand tall by extending the hips; avoid leaning backward at the top.',
    ],
    imagePaths: ['Romanian_Deadlift/0.jpg', 'Romanian_Deadlift/1.jpg'],
    goals: {TrainingGoal.buildMuscle, TrainingGoal.getStronger},
    defaultSets: 3,
    defaultReps: '6–10 reps',
    restSeconds: 120,
  ),
  ExerciseGuide(
    id: 'Standing_Military_Press',
    name: 'Standing overhead press',
    level: 'Beginner',
    equipment: 'Barbell',
    primaryMuscle: 'Shoulders',
    secondaryMuscles: ['Triceps'],
    instructions: [
      'Start with the bar supported near your upper chest and brace your trunk.',
      'Press overhead while keeping the bar path controlled.',
      'Lower slowly to the starting position without overextending your lower back.',
    ],
    imagePaths: [
      'Standing_Military_Press/0.jpg',
      'Standing_Military_Press/1.jpg',
    ],
    goals: {TrainingGoal.buildMuscle, TrainingGoal.getStronger},
    defaultSets: 3,
    defaultReps: '6–10 reps',
    restSeconds: 90,
  ),
  ExerciseGuide(
    id: 'Childs_Pose',
    name: "Child's pose",
    level: 'Beginner',
    equipment: 'Bodyweight',
    primaryMuscle: 'Lower back',
    secondaryMuscles: ['Lats'],
    instructions: [
      'Kneel comfortably and sit your hips back toward your heels.',
      'Reach your arms forward and let your chest move gently toward the floor.',
      'Breathe slowly and stay within a comfortable, pain-free range.',
    ],
    imagePaths: ['Childs_Pose/0.jpg', 'Childs_Pose/1.jpg'],
    goals: {TrainingGoal.mobility},
    defaultSets: 2,
    defaultReps: '30–60 sec',
    restSeconds: 30,
  ),
];

List<ExerciseGuide> exercisesForGoal(TrainingGoal goal, {int? limit}) {
  final matches = exerciseGuides
      .where((exercise) => exercise.goals.contains(goal))
      .toList(growable: false);
  if (limit == null || matches.length <= limit) return matches;
  return matches.take(limit).toList(growable: false);
}
