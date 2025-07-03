// Example seeding script (e.g., seed.js or within a test setup)
const mongoose = require("mongoose");
const HealthGoal = require("../../dist/models/health-goals").default;
const WorkoutFrequency = require("../../dist/models/workout-frequency").default;
const Workout = require("../../dist/models/workout").default;

async function seedOptions() {
  const mongoUri =
    process.env.MONGO_URI || "mongodb://localhost:27017/fitness-app";
  await mongoose.connect(mongoUri); // Your DB connection string

  await HealthGoal.deleteMany({});
  await WorkoutFrequency.deleteMany({});
  await Workout.deleteMany({});

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

  // 100 original workouts
  const workouts = [
    {
      name: "Sunrise Yoga Stretch",
      description: "Start your day with gentle yoga poses to awaken the body.",
      category: "Yoga",
      difficulty: "Beginner",
    },
    {
      name: "Power Walk in the Park",
      description: "A brisk walk focusing on posture and breathing.",
      category: "Walking",
      difficulty: "Beginner",
    },
    {
      name: "Bodyweight Blast",
      description:
        "A circuit of squats, push-ups, and lunges for total body strength.",
      category: "Strength",
      difficulty: "Intermediate",
    },
    {
      name: "Cardio Kickboxing",
      description:
        "Punch and kick your way through a high-energy cardio session.",
      category: "Cardio",
      difficulty: "Intermediate",
    },
    {
      name: "Pilates for Posture",
      description: "Pilates moves to strengthen your core and improve posture.",
      category: "Pilates",
      difficulty: "Beginner",
    },
    {
      name: "Tabata Torch",
      description:
        "Intense 4-minute intervals of work and rest for fat burning.",
      category: "HIIT",
      difficulty: "Advanced",
    },
    {
      name: "Core Stability Flow",
      description: "A series of planks and holds to build core stability.",
      category: "Core",
      difficulty: "Intermediate",
    },
    {
      name: "Mobility Morning",
      description: "Dynamic stretches to increase joint mobility.",
      category: "Mobility",
      difficulty: "Beginner",
    },
    {
      name: "Evening Relaxation Yoga",
      description: "Wind down with restorative yoga poses.",
      category: "Yoga",
      difficulty: "Beginner",
    },
    {
      name: "Stair Climber Challenge",
      description: "Climb stairs for a powerful lower body and cardio workout.",
      category: "Cardio",
      difficulty: "Intermediate",
    },
    {
      name: "Upper Body Strength",
      description: "Push-ups, dips, and rows to build upper body muscle.",
      category: "Strength",
      difficulty: "Intermediate",
    },
    {
      name: "Dance Cardio Party",
      description: "Fun, rhythmic dance moves to get your heart pumping.",
      category: "Dance",
      difficulty: "Beginner",
    },
    {
      name: "Balance & Stability",
      description: "Single-leg exercises to improve balance and coordination.",
      category: "Balance",
      difficulty: "Beginner",
    },
    {
      name: "Cycling Endurance Ride",
      description: "A steady-state cycling session for cardiovascular health.",
      category: "Cycling",
      difficulty: "Intermediate",
    },
    {
      name: "Full Body Stretch",
      description: "A relaxing routine to stretch all major muscle groups.",
      category: "Stretching",
      difficulty: "Beginner",
    },
    {
      name: "CrossFit AMRAP",
      description:
        "As many rounds as possible of squats, burpees, and sit-ups.",
      category: "CrossFit",
      difficulty: "Advanced",
    },
    {
      name: "Hill Sprints",
      description: "Short, intense sprints up a hill to build power.",
      category: "Running",
      difficulty: "Advanced",
    },
    {
      name: "Pilates Abs Burner",
      description: "Target your abs with classic Pilates moves.",
      category: "Pilates",
      difficulty: "Intermediate",
    },
    {
      name: "Jump Rope Intervals",
      description: "Alternate between fast and slow jump rope sets.",
      category: "Cardio",
      difficulty: "Intermediate",
    },
    {
      name: "Gentle Chair Yoga",
      description: "Yoga poses adapted for sitting in a chair.",
      category: "Yoga",
      difficulty: "Beginner",
    },
    {
      name: "Resistance Band Workout",
      description: "Strengthen muscles using resistance bands.",
      category: "Strength",
      difficulty: "Beginner",
    },
    {
      name: "Aquatic Aerobics",
      description: "Low-impact cardio in the pool.",
      category: "Swimming",
      difficulty: "Beginner",
    },
    {
      name: "Boxing Basics",
      description: "Learn basic boxing footwork and punches.",
      category: "Cardio",
      difficulty: "Beginner",
    },
    {
      name: "Power Yoga Flow",
      description: "A faster-paced yoga session for strength and flexibility.",
      category: "Yoga",
      difficulty: "Intermediate",
    },
    {
      name: "Sprint Intervals",
      description: "Short, fast sprints with walking recovery.",
      category: "Running",
      difficulty: "Intermediate",
    },
    {
      name: "Lower Body Burn",
      description: "Lunges, squats, and glute bridges for legs and glutes.",
      category: "Strength",
      difficulty: "Intermediate",
    },
    {
      name: "Foam Rolling Recovery",
      description: "Release muscle tension with foam rolling techniques.",
      category: "Mobility",
      difficulty: "Beginner",
    },
    {
      name: "Step Aerobics",
      description: "Step up and down to music for a fun cardio workout.",
      category: "Cardio",
      difficulty: "Beginner",
    },
    {
      name: "TRX Suspension Training",
      description: "Bodyweight exercises using TRX straps.",
      category: "Strength",
      difficulty: "Advanced",
    },
    {
      name: "Stretch & Breathe",
      description: "Gentle stretching combined with deep breathing.",
      category: "Stretching",
      difficulty: "Beginner",
    },
    {
      name: "Pilates Leg Sculpt",
      description: "Pilates moves to tone and lengthen your legs.",
      category: "Pilates",
      difficulty: "Intermediate",
    },
    {
      name: "Mountain Climber Madness",
      description: "High-rep mountain climbers for cardio and core.",
      category: "HIIT",
      difficulty: "Advanced",
    },
    {
      name: "Walking Meditation",
      description: "Mindful walking for relaxation and focus.",
      category: "Walking",
      difficulty: "Beginner",
    },
    {
      name: "Kettlebell Power",
      description: "Swings, cleans, and snatches for full-body strength.",
      category: "Strength",
      difficulty: "Advanced",
    },
    {
      name: "Sunset Yoga Flow",
      description: "Unwind with calming yoga as the sun sets.",
      category: "Yoga",
      difficulty: "Beginner",
    },
    {
      name: "Interval Cycling",
      description: "Alternate between sprints and recovery on the bike.",
      category: "Cycling",
      difficulty: "Intermediate",
    },
    {
      name: "Jumping Jacks & Friends",
      description: "A fun mix of jumping jacks, high knees, and butt kicks.",
      category: "Cardio",
      difficulty: "Beginner",
    },
    {
      name: "Core & More",
      description: "Planks, crunches, and twists for a strong core.",
      category: "Core",
      difficulty: "Intermediate",
    },
    {
      name: "Balance Ball Workout",
      description: "Use a stability ball for balance and strength.",
      category: "Balance",
      difficulty: "Intermediate",
    },
    {
      name: "Swim Endurance Laps",
      description: "Continuous swimming to build stamina.",
      category: "Swimming",
      difficulty: "Intermediate",
    },
    {
      name: "Box Jumps & Burpees",
      description: "Explosive plyometric moves for power.",
      category: "HIIT",
      difficulty: "Advanced",
    },
    {
      name: "Gentle Morning Stretch",
      description: "Wake up your body with easy stretches.",
      category: "Stretching",
      difficulty: "Beginner",
    },
    {
      name: "Rowing Machine Intervals",
      description: "Row hard, rest, and repeat for a cardio challenge.",
      category: "Cardio",
      difficulty: "Intermediate",
    },
    {
      name: "Pilates Back Care",
      description: "Strengthen and stretch your back with Pilates.",
      category: "Pilates",
      difficulty: "Beginner",
    },
    {
      name: "CrossFit EMOM",
      description: "Every minute on the minute: push yourself with new reps.",
      category: "CrossFit",
      difficulty: "Advanced",
    },
    {
      name: "Outdoor Trail Run",
      description: "Run on trails for a change of scenery and terrain.",
      category: "Running",
      difficulty: "Intermediate",
    },
    {
      name: "Standing Core Series",
      description: "Core exercises you can do standing up.",
      category: "Core",
      difficulty: "Beginner",
    },
    {
      name: "Aqua Jogging",
      description: "Jog in the pool for low-impact cardio.",
      category: "Swimming",
      difficulty: "Beginner",
    },
    {
      name: "Dynamic Warm-Up",
      description: "Prepare your body for exercise with dynamic moves.",
      category: "Mobility",
      difficulty: "Beginner",
    },
    {
      name: "Strength Endurance Circuit",
      description: "Combine strength and endurance in one workout.",
      category: "Strength",
      difficulty: "Intermediate",
    },
    {
      name: "Hip Mobility Flow",
      description: "Open up your hips with targeted stretches.",
      category: "Mobility",
      difficulty: "Beginner",
    },
    {
      name: "Boxing HIIT",
      description: "Alternate boxing combos with high-intensity intervals.",
      category: "HIIT",
      difficulty: "Advanced",
    },
    {
      name: "Gentle Pilates Flow",
      description: "A slow-paced Pilates session for all levels.",
      category: "Pilates",
      difficulty: "Beginner",
    },
    {
      name: "Jump Squat Challenge",
      description: "Test your power with sets of jump squats.",
      category: "Strength",
      difficulty: "Advanced",
    },
    {
      name: "Balance Beam Basics",
      description: "Simple moves to improve balance and focus.",
      category: "Balance",
      difficulty: "Beginner",
    },
    {
      name: "Cardio Ladder",
      description: "Increase intensity with each round of cardio moves.",
      category: "Cardio",
      difficulty: "Intermediate",
    },
    {
      name: "Yoga for Runners",
      description: "Yoga poses to stretch and strengthen running muscles.",
      category: "Yoga",
      difficulty: "Beginner",
    },
    {
      name: "Sprint Pyramid",
      description: "Increase and decrease sprint times for a challenge.",
      category: "Running",
      difficulty: "Advanced",
    },
    {
      name: "Resistance Band Glutes",
      description: "Target your glutes with banded exercises.",
      category: "Strength",
      difficulty: "Intermediate",
    },
    {
      name: "Foam Roller Flow",
      description: "Move through foam rolling for recovery.",
      category: "Mobility",
      difficulty: "Beginner",
    },
    {
      name: "Pilates Powerhouse",
      description: "Focus on the core with classic Pilates moves.",
      category: "Pilates",
      difficulty: "Intermediate",
    },
    {
      name: "Step Up Strength",
      description: "Use a step for lower body strength exercises.",
      category: "Strength",
      difficulty: "Beginner",
    },
    {
      name: "Cardio Dance Fusion",
      description: "Blend dance styles for a fun cardio workout.",
      category: "Dance",
      difficulty: "Intermediate",
    },
    {
      name: "Yoga for Flexibility",
      description: "Deep stretches to improve flexibility.",
      category: "Yoga",
      difficulty: "Beginner",
    },
    {
      name: "Core HIIT Express",
      description: "Quick HIIT session focused on the core.",
      category: "HIIT",
      difficulty: "Intermediate",
    },
    {
      name: "Walking Hills",
      description: "Walk up and down hills for a cardio boost.",
      category: "Walking",
      difficulty: "Intermediate",
    },
    {
      name: "Strength & Stretch",
      description: "Alternate strength moves with stretching.",
      category: "Strength",
      difficulty: "Beginner",
    },
    {
      name: "Balance Challenge",
      description: "Test your balance with single-leg moves.",
      category: "Balance",
      difficulty: "Intermediate",
    },
    {
      name: "Cycling Power Intervals",
      description: "Short bursts of high resistance cycling.",
      category: "Cycling",
      difficulty: "Advanced",
    },
    {
      name: "Gentle Evening Stretch",
      description: "Relax and stretch before bed.",
      category: "Stretching",
      difficulty: "Beginner",
    },
    {
      name: "CrossFit Ladder",
      description: "Increase reps each round for a CrossFit challenge.",
      category: "CrossFit",
      difficulty: "Advanced",
    },
    {
      name: "Pilates Stretch Series",
      description: "A series of Pilates stretches for flexibility.",
      category: "Pilates",
      difficulty: "Beginner",
    },
    {
      name: "Jump Rope Cardio",
      description: "Continuous jump rope for heart health.",
      category: "Cardio",
      difficulty: "Intermediate",
    },
    {
      name: "Yoga for Stress Relief",
      description: "Calming poses to reduce stress.",
      category: "Yoga",
      difficulty: "Beginner",
    },
    {
      name: "Interval Run & Walk",
      description: "Alternate running and walking for endurance.",
      category: "Running",
      difficulty: "Beginner",
    },
    {
      name: "Upper Body Blast",
      description: "Push, pull, and press for upper body strength.",
      category: "Strength",
      difficulty: "Intermediate",
    },
    {
      name: "Dance HIIT",
      description: "Combine dance moves with HIIT intervals.",
      category: "Dance",
      difficulty: "Advanced",
    },
    {
      name: "Mobility for Athletes",
      description: "Mobility drills for active individuals.",
      category: "Mobility",
      difficulty: "Intermediate",
    },
    {
      name: "Gentle Pool Workout",
      description: "Low-impact pool exercises for all levels.",
      category: "Swimming",
      difficulty: "Beginner",
    },
    {
      name: "Core Balance Flow",
      description: "Balance and core moves for stability.",
      category: "Core",
      difficulty: "Intermediate",
    },
    {
      name: "Strength for Runners",
      description: "Strengthen running muscles with targeted moves.",
      category: "Strength",
      difficulty: "Intermediate",
    },
    {
      name: "Stretch & Strengthen",
      description: "Stretch and strengthen in one session.",
      category: "Stretching",
      difficulty: "Beginner",
    },
    {
      name: "Pilates for Athletes",
      description: "Pilates moves to support athletic performance.",
      category: "Pilates",
      difficulty: "Intermediate",
    },
    {
      name: "Cardio Core Circuit",
      description: "Alternate cardio and core exercises.",
      category: "Cardio",
      difficulty: "Intermediate",
    },
    {
      name: "Yoga for Back Pain",
      description: "Yoga poses to relieve back discomfort.",
      category: "Yoga",
      difficulty: "Beginner",
    },
    {
      name: "Sprint & Recover",
      description: "Sprint hard, then recover with walking.",
      category: "Running",
      difficulty: "Intermediate",
    },
    {
      name: "Strength Supersets",
      description: "Pair strength moves for maximum effect.",
      category: "Strength",
      difficulty: "Advanced",
    },
    {
      name: "Balance & Core Fusion",
      description: "Combine balance and core exercises.",
      category: "Balance",
      difficulty: "Intermediate",
    },
    {
      name: "Cycling Hill Climb",
      description: "Simulate hill climbs on the bike.",
      category: "Cycling",
      difficulty: "Advanced",
    },
    {
      name: "Gentle Wake-Up Yoga",
      description: "Easy yoga to start your morning.",
      category: "Yoga",
      difficulty: "Beginner",
    },
    {
      name: "HIIT Cardio Circuit",
      description: "High-intensity cardio moves in a circuit.",
      category: "HIIT",
      difficulty: "Advanced",
    },
    {
      name: "Pilates Stretch & Strength",
      description: "Blend Pilates stretching and strength.",
      category: "Pilates",
      difficulty: "Intermediate",
    },
    {
      name: "Walking Intervals",
      description: "Alternate fast and slow walking.",
      category: "Walking",
      difficulty: "Beginner",
    },
    {
      name: "Strength Fundamentals",
      description: "Learn the basics of strength training.",
      category: "Strength",
      difficulty: "Beginner",
    },
    {
      name: "Balance for Seniors",
      description: "Gentle balance exercises for older adults.",
      category: "Balance",
      difficulty: "Beginner",
    },
    {
      name: "Cardio Endurance Run",
      description: "Long, steady run for endurance.",
      category: "Running",
      difficulty: "Intermediate",
    },
    {
      name: "Stretch & Flow",
      description: "Stretching with flowing movements.",
      category: "Stretching",
      difficulty: "Beginner",
    },
    {
      name: "CrossFit Tabata",
      description: "Tabata intervals with CrossFit moves.",
      category: "CrossFit",
      difficulty: "Advanced",
    },
    {
      name: "Pilates Mat Basics",
      description: "Fundamental Pilates mat exercises.",
      category: "Pilates",
      difficulty: "Beginner",
    },
    {
      name: "Cardio Step Blast",
      description: "Step up the pace with this cardio workout.",
      category: "Cardio",
      difficulty: "Intermediate",
    },
    {
      name: "Yoga for Athletes",
      description: "Yoga to support athletic recovery.",
      category: "Yoga",
      difficulty: "Intermediate",
    },
    {
      name: "Interval Swim",
      description: "Alternate fast and slow laps in the pool.",
      category: "Swimming",
      difficulty: "Intermediate",
    },
    {
      name: "Core Strength Builder",
      description: "Build core strength with targeted moves.",
      category: "Core",
      difficulty: "Intermediate",
    },
    {
      name: "Strength & Cardio Mix",
      description: "Combine strength and cardio in one session.",
      category: "Strength",
      difficulty: "Intermediate",
    },
    {
      name: "Balance Yoga Flow",
      description: "Yoga poses to improve balance.",
      category: "Yoga",
      difficulty: "Beginner",
    },
    {
      name: "Cycling Sprints",
      description: "Short, fast cycling intervals.",
      category: "Cycling",
      difficulty: "Advanced",
    },
    {
      name: "Gentle Stretch Routine",
      description: "A gentle stretch for the whole body.",
      category: "Stretching",
      difficulty: "Beginner",
    },
    {
      name: "HIIT Express",
      description: "A quick, intense HIIT workout.",
      category: "HIIT",
      difficulty: "Advanced",
    },
    {
      name: "Pilates for Flexibility",
      description: "Pilates moves to increase flexibility.",
      category: "Pilates",
      difficulty: "Beginner",
    },
    {
      name: "Walking for Wellness",
      description: "A relaxing walk for overall wellness.",
      category: "Walking",
      difficulty: "Beginner",
    },
  ];

  await Workout.insertMany(workouts);

  console.log("Options seeded successfully!");
  await mongoose.disconnect();
}

seedOptions().catch(console.error);
