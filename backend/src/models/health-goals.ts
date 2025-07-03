import mongoose, { Document, Schema } from "mongoose";

export interface IHealthGoal extends Document {
  name: string;
  description?: string;
  createdAt: Date;
  updatedAt: Date;
}

const HealthGoalSchema = new Schema<IHealthGoal>({
  name: { type: String, required: true, unique: true },
  description: { type: String },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

const HealthGoal = mongoose.model<IHealthGoal>("HealthGoal", HealthGoalSchema);
export default HealthGoal;
