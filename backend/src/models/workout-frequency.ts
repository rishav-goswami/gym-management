import mongoose, { Document, Schema, ObjectId } from "mongoose";

export interface IWorkoutFrequency extends Document {
  _id: ObjectId;
  label: string; // e.g. "3-4 times a week"
}

const WorkoutFrequencySchema = new Schema<IWorkoutFrequency>({
  label: { type: String, required: true, unique: true },
});

const WorkoutFrequency = mongoose.model<IWorkoutFrequency>(
  "WorkoutFrequency",
  WorkoutFrequencySchema
);
export default WorkoutFrequency;
