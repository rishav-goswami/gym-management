import mongoose, { Document, Schema, Types } from "mongoose";

export interface IWorkout extends Document {
  _id: Types.ObjectId;
  name: string;
  description?: string;
  category?: string;
  difficulty?: string;
  createdAt: Date;
  updatedAt: Date;
}

const WorkoutSchema = new Schema<IWorkout>({
  name: { type: String, required: true },
  description: { type: String },
  category: { type: String },
  difficulty: { type: String },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

const Workout = mongoose.model<IWorkout>("Workout", WorkoutSchema);
export default Workout;
