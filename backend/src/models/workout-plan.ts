import { Document, Schema, model, Types } from "mongoose";

// Defines a single exercise within a day's plan
interface IDailyExercise {
  exerciseId: Types.ObjectId; // Reference to the Exercise model
  sets: number;
  reps: string; // e.g., "8-12", "15"
  rest: string; // e.g., "60 seconds"
  notes?: string;
}

// Defines a full day's workout
interface IDailyWorkout {
  day:
    | "Monday"
    | "Tuesday"
    | "Wednesday"
    | "Thursday"
    | "Friday"
    | "Saturday"
    | "Sunday";
  exercises: IDailyExercise[];
}

// The main interface for the entire weekly workout plan
export interface IWorkoutPlan extends Document {
  userId: Types.ObjectId;
  trainerId: Types.ObjectId;
  weekStartDate: Date;
  days: IDailyWorkout[];
}

const WorkoutPlanSchema = new Schema<IWorkoutPlan>(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    trainerId: { type: Schema.Types.ObjectId, ref: "Trainer", required: true },
    weekStartDate: { type: Date, required: true },
    days: [
      {
        day: {
          type: String,
          required: true,
          enum: [
            "Monday",
            "Tuesday",
            "Wednesday",
            "Thursday",
            "Friday",
            "Saturday",
            "Sunday",
          ],
        },
        exercises: [
          {
            exerciseId: {
              type: Schema.Types.ObjectId,
              ref: "Exercise",
              required: true,
            },
            sets: { type: Number, required: true },
            reps: { type: String, required: true },
            rest: { type: String, required: true },
            notes: { type: String },
          },
        ],
      },
    ],
  },
  { timestamps: true }
);

const WorkoutPlan = model<IWorkoutPlan>("WorkoutPlan", WorkoutPlanSchema);
export default WorkoutPlan;
