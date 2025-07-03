import mongoose, { Document, Schema } from "mongoose";

export interface IWorkoutFrequency extends Document {
  name: string; // e.g., "3-4 times a week"
  value: string; // e.g., "3-4" or "moderate" (for internal logic if needed)
  description?: string;
  createdAt: Date;
  updatedAt: Date;
}

const WorkoutFrequencySchema = new Schema<IWorkoutFrequency>({
  name: { type: String, required: true, unique: true },
  value: { type: String, required: true, unique: true },
  description: { type: String },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

const WorkoutFrequency = mongoose.model<IWorkoutFrequency>(
  "WorkoutFrequency",
  WorkoutFrequencySchema
);
export default WorkoutFrequency;
