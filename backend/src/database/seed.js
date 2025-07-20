// Example seeding script (e.g., seed.js or within a test setup)
const mongoose = require("mongoose");
const HealthGoal = require("../../dist/models/health-goals").default;
const WorkoutFrequency = require("../../dist/models/workout-frequency").default;
const Exercise = require("../../dist/models/exercise").default;

async function seedOptions() {
  const mongoUri =
    process.env.MONGO_URI || "mongodb://localhost:27017/fitness_app";
  await mongoose.connect(mongoUri); // Your DB connection string

  await HealthGoal.deleteMany({});
  await WorkoutFrequency.deleteMany({});
  await Exercise.deleteMany({});

  const healthGoals = await HealthGoal.insertMany([
    { name: "Weight Loss" },
    { name: "Muscle Gain" },
    { name: "Improve Endurance" },
    { name: "Maintain Fitness" },
    { name: "Stress Reduction" },
    { name: "Increase Flexibility" },
    { name: "Improve Balance" },
    { name: "Boost Immunity" },
    { name: "Improve Sleep" },
    { name: "Increase Energy" },
    { name: "Rehabilitation" },
    { name: "Improve Posture" },
    { name: "Healthy Aging" },
    { name: "Sports Performance" },
    { name: "General Wellness" },
  ]);

  const workoutFrequencies = await WorkoutFrequency.insertMany([
    { "name": "1-2 times a week", "value": "light" },
    { "name": "3-4 times a week", "value": "moderate" },
    { "name": "5+ times a week", "value": "frequent" },
    { "name": "Daily", "value": "daily" },
    { "name": "Twice Daily", "value": "twice_daily" },
    { "name": "Occasionally", "value": "occasional" },
    { "name": "Every Other Day", "value": "alternate" },
  ]);

   // --- Seed Exercise Library (100 Exercises) ---
  console.log("Seeding new exercise library...");
  
  const placeholderTrainerId = new mongoose.Types.ObjectId();

  const exercises = [
    // Chest (15)
    { name: "Barbell Bench Press", description: "The primary horizontal press for upper body strength.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Incline Dumbbell Press", description: "Targets the upper portion of the pectoral muscles.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Decline Barbell Press", description: "Targets the lower portion of the pectoral muscles.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Dumbbell Flys", description: "An isolation exercise to stretch and build the chest.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Incline Cable Flys", description: "Constant tension isolation for the upper chest.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Push-ups", description: "A classic bodyweight exercise for chest, shoulders, and triceps.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Dips", description: "A compound bodyweight exercise targeting the chest and triceps.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Machine Chest Press", description: "A stable, machine-based alternative to the bench press.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Pec Deck Machine", description: "An isolation machine for the chest muscles.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Svend Press", description: "An isometric-style press using two plates squeezed together.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Cable Crossover", description: "A versatile isolation exercise for the entire chest.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Single-Arm Dumbbell Press", description: "Improves unilateral strength and core stability.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Wide-Grip Push-ups", description: "Emphasizes the chest more than standard push-ups.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Floor Press", description: "A partial range-of-motion press that's great for lockout strength.", muscleGroup: "Chest", createdBy: placeholderTrainerId },
    { name: "Guillotine Press", description: "A bench press variation where the bar is lowered to the neck.", muscleGroup: "Chest", createdBy: placeholderTrainerId },

    // Back (15)
    { name: "Deadlift", description: "A full-body compound lift, primarily targeting the posterior chain.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "Pull-ups", description: "An advanced bodyweight exercise for upper back and bicep strength.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "Chin-ups", description: "Similar to pull-ups but with more emphasis on the biceps.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "Barbell Rows", description: "A compound exercise for building a thick, strong back.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "Pendlay Rows", description: "A stricter barbell row variation that starts from the floor.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "T-Bar Rows", description: "A classic machine or barbell row for mid-back thickness.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "Lat Pulldowns", description: "A machine-based exercise to simulate pull-ups and target the lats.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "Seated Cable Rows", description: "A cable exercise for targeting the mid-back muscles.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "Single-Arm Dumbbell Rows", description: "Builds unilateral back strength and core stability.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "Face Pulls", description: "An essential exercise for rear deltoid and upper back health.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "Good Mornings", description: "A hip-hinge exercise for the lower back, glutes, and hamstrings.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "Hyperextensions", description: "Targets the lower back and glutes.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "Rack Pulls", description: "A partial range-of-motion deadlift to overload the upper back.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "Straight-Arm Pulldowns", description: "An isolation exercise for the lats.", muscleGroup: "Back", createdBy: placeholderTrainerId },
    { name: "Renegade Rows", description: "A challenging push-up and row combination for the full body.", muscleGroup: "Back", createdBy: placeholderTrainerId },

    // Legs (20)
    { name: "Barbell Back Squats", description: "The king of leg exercises, targeting quads, hamstrings, and glutes.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Front Squats", description: "A squat variation that places more emphasis on the quads.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Goblet Squats", description: "A beginner-friendly squat variation using a single dumbbell or kettlebell.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Leg Press", description: "A machine-based alternative to squats for building leg mass.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Lunges", description: "A unilateral exercise excellent for balance and leg strength.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Walking Lunges", description: "A dynamic lunge variation that challenges coordination.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Bulgarian Split Squats", description: "An advanced unilateral squat for targeting each leg individually.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Romanian Deadlifts (RDLs)", description: "Targets the hamstrings and glutes with a focus on stretching.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Lying Leg Curls", description: "An isolation machine exercise for the hamstrings.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Seated Leg Curls", description: "Another hamstring isolation exercise with a different strength curve.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Leg Extensions", description: "An isolation machine exercise for the quadriceps.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Calf Raises", description: "Targets the gastrocnemius and soleus muscles of the calf.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Hip Thrusts", description: "A primary exercise for building glute strength and size.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Box Jumps", description: "A plyometric exercise for developing explosive power.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Hack Squats", description: "A machine squat that provides excellent quad development.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Sissy Squats", description: "An advanced bodyweight exercise for quad isolation.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Step-ups", description: "A functional exercise for single-leg strength and stability.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Kettlebell Swings", description: "A dynamic, full-body movement with emphasis on the posterior chain.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Pistol Squats", description: "An advanced single-leg bodyweight squat.", muscleGroup: "Legs", createdBy: placeholderTrainerId },
    { name: "Adductor Machine", description: "Targets the inner thigh muscles.", muscleGroup: "Legs", createdBy: placeholderTrainerId },

    // Shoulders (15)
    { name: "Overhead Press (OHP)", description: "A primary compound lift for building strong shoulders.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Dumbbell Shoulder Press", description: "A dumbbell alternative to the OHP, allowing for more natural movement.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Arnold Press", description: "A dumbbell press variation that hits all three heads of the deltoid.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Lateral Raises", description: "An isolation exercise for the medial deltoid, creating shoulder width.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Front Raises", description: "An isolation exercise for the anterior deltoid.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Bent-Over Dumbbell Raises", description: "Targets the rear deltoids.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Upright Rows", description: "A compound movement for the shoulders and traps.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Shrugs", description: "Targets the trapezius muscles.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Pike Push-ups", description: "A bodyweight progression towards handstand push-ups.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Handstand Push-ups", description: "An advanced bodyweight exercise for shoulder strength.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Cable Lateral Raises", description: "Provides constant tension on the medial deltoid.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Reverse Pec Deck", description: "A machine exercise for the rear deltoids.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Landmine Press", description: "A shoulder-friendly pressing variation.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Bus Drivers", description: "A plate exercise for shoulder stability and endurance.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },
    { name: "Scott Press", description: "A unique dumbbell press for shoulder mobility and strength.", muscleGroup: "Shoulders", createdBy: placeholderTrainerId },

    // Arms (15)
    { name: "Barbell Bicep Curls", description: "A mass-builder for the biceps.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Dumbbell Hammer Curls", description: "Targets the biceps and brachialis for thicker arms.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Preacher Curls", description: "Isolates the biceps by preventing cheating.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Concentration Curls", description: "A classic exercise for building the bicep peak.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Cable Curls", description: "Provides constant tension on the biceps.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Skull Crushers", description: "A primary exercise for tricep mass.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Tricep Pushdowns", description: "A cable machine exercise to target the triceps.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Overhead Tricep Extensions", description: "Targets the long head of the triceps.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Close-Grip Bench Press", description: "A compound lift with emphasis on the triceps.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Diamond Push-ups", description: "A bodyweight exercise that heavily targets the triceps.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Wrist Curls", description: "Strengthens the forearm flexors.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Reverse Wrist Curls", description: "Strengthens the forearm extensors.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Zottman Curls", description: "A unique curl that works both biceps and forearms.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Spider Curls", description: "An incline bench curl that provides a great bicep stretch.", muscleGroup: "Arms", createdBy: placeholderTrainerId },
    { name: "Tate Press", description: "A dumbbell press variation for the triceps.", muscleGroup: "Arms", createdBy: placeholderTrainerId },

    // Core (10)
    { name: "Crunches", description: "A basic exercise for the upper abdominals.", muscleGroup: "Core", createdBy: placeholderTrainerId },
    { name: "Leg Raises", description: "Targets the lower abdominals.", muscleGroup: "Core", createdBy: placeholderTrainerId },
    { name: "Plank", description: "An isometric exercise for core stability.", muscleGroup: "Core", createdBy: placeholderTrainerId },
    { name: "Side Plank", description: "Targets the obliques and improves core stability.", muscleGroup: "Core", createdBy: placeholderTrainerId },
    { name: "Russian Twists", description: "A rotational exercise for the obliques.", muscleGroup: "Core", createdBy: placeholderTrainerId },
    { name: "Hanging Leg Raises", description: "An advanced core exercise for the lower abs and hip flexors.", muscleGroup: "Core", createdBy: placeholderTrainerId },
    { name: "Ab Rollouts", description: "A challenging exercise for the entire core.", muscleGroup: "Core", createdBy: placeholderTrainerId },
    { name: "Cable Crunches", description: "Allows for weighted resistance to be added to crunches.", muscleGroup: "Core", createdBy: placeholderTrainerId },
    { name: "Wood Chops", description: "A functional, rotational core exercise.", muscleGroup: "Core", createdBy: placeholderTrainerId },
    { name: "Bird Dog", description: "A great exercise for lower back stability and core control.", muscleGroup: "Core", createdBy: placeholderTrainerId },

    // Cardio/Full Body (10)
    { name: "Burpees", description: "A full-body calisthenics exercise that builds strength and endurance.", muscleGroup: "Full Body", createdBy: placeholderTrainerId },
    { name: "Jumping Jacks", description: "A classic full-body warm-up and cardio exercise.", muscleGroup: "Full Body", createdBy: placeholderTrainerId },
    { name: "Mountain Climbers", description: "A dynamic core and cardio exercise.", muscleGroup: "Full Body", createdBy: placeholderTrainerId },
    { name: "Rowing Machine", description: "A low-impact, full-body cardio workout.", muscleGroup: "Full Body", createdBy: placeholderTrainerId },
    { name: "Battle Ropes", description: "A high-intensity workout for conditioning and strength.", muscleGroup: "Full Body", createdBy: placeholderTrainerId },
    { name: "Tire Flips", description: "A functional, full-body strength and conditioning exercise.", muscleGroup: "Full Body", createdBy: placeholderTrainerId },
    { name: "Sled Pushes", description: "Develops leg power and cardiovascular endurance.", muscleGroup: "Full Body", createdBy: placeholderTrainerId },
    { name: "Farmer's Walk", description: "Builds grip strength, core stability, and overall toughness.", muscleGroup: "Full Body", createdBy: placeholderTrainerId },
    { name: "Box Squats", description: "A squat variation that builds explosive power from a dead stop.", muscleGroup: "Full Body", createdBy: placeholderTrainerId },
    { name: "Thrusters", description: "A combination of a front squat and an overhead press.", muscleGroup: "Full Body", createdBy: placeholderTrainerId },
  ];

  await Exercise.insertMany(exercises);

  console.log("Options seeded successfully!");
  await mongoose.disconnect();
}

seedOptions().catch(console.error);
