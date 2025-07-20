import mongoose, { Document, Schema, Types } from "mongoose";

//  TODO: Rename it as Exercise
export interface IExercise  extends Document {
  _id: Types.ObjectId;
  name: string;
  description?: string;
  category?: string;
  difficulty?: string;
  createdAt: Date;
  updatedAt: Date;
  muscleGroup: String;
  videoUrl?: String;
  createdBy?: Types.ObjectId; // The trainer or admin who added it
}

const ExerciseSchema = new Schema<IExercise >({
  name: { type: String, required: true },
  description: { type: String },
  category: { type: String },
  difficulty: { type: String },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
  muscleGroup: { type: String, required: true },
  videoUrl: { type: String },
  createdBy: { type: Schema.Types.ObjectId, ref: "Trainer" },
});

const Exercise = mongoose.model<IExercise>("Exercise", ExerciseSchema);
export default Exercise;
