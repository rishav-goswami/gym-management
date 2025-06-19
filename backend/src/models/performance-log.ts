import mongoose, { Document, Schema, ObjectId} from "mongoose";

interface PerformanceLog {
  date: Date,
  weight: number,
  caloriesBurned: number,
  notes?: string
}

export const PerformanceLogSchema = new Schema({
  date: { type: Date, required: true },
  weight: { type: Number, required: true },
  caloriesBurned: { type: Number, required: true },
  notes: { type: String },
});