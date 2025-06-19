// backend/src/models/user.ts
import mongoose, { Document, Schema, ObjectId } from "mongoose";
import bcrypt from "bcryptjs";

export interface IUser extends Document {
  _id: ObjectId;
  name: string;
  email: string;
  password: string;
  avatarUrl?: string; // URL or asset name for avatar
  role: "user" | "trainer" | "admin";
  trainerId?: ObjectId;
  healthGoals: string;
  subscription: ObjectId; // Reference to Subscription
  performance: ObjectId[]; // Reference to PerformanceLog
  age?: number;
  gender?: "male" | "female" | "other";
  height?: number; // in cm
  weight?: number; // in kg
  bio?: string;
  createdAt: Date;
  updatedAt: Date;
}
interface User {}
const UserSchema = new Schema<IUser>({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  avatarUrl: { type: String },
  role: { type: String, enum: ["user", "trainer", "admin"], required: true },
  trainerId: { type: Schema.Types.ObjectId, ref: "Trainer" },
  healthGoals: { type: String },
  subscription: { type: Schema.Types.ObjectId, ref: "Subscription" },
  performance: [{ type: Schema.Types.ObjectId, ref: "PerformanceLog" }],
  age: { type: Number },
  gender: { type: String, enum: ["male", "female", "other"] },
  height: { type: Number },
  weight: { type: Number },
  bio: { type: String },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

UserSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (err) {
    next(err as Error);
  }
});

UserSchema.methods.comparePassword = async function (
  candidatePassword: string
) {
  return bcrypt.compare(candidatePassword, this.password);
};

const User = mongoose.model<IUser>("User", UserSchema);
export default User;
