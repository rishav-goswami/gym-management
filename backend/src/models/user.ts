import mongoose, { Document, Schema, Model, Types } from "mongoose";
import bcrypt from "bcryptjs";

// Methods attached to user instance
interface IUserMethods {
  comparePassword(candidatePassword: string): Promise<boolean>;
}

// Document with both props and methods
export interface IUser extends Document, IUserMethods {
  _id: Types.ObjectId;
  name: string;
  email: string;
  password: string;
  avatarUrl?: string;
  role: "user" | "trainer" | "admin";
  trainerId?: Types.ObjectId;
  healthGoals: string;
  subscription: Types.ObjectId;
  performance: Types.ObjectId[];
  age?: number;
  gender?: "male" | "female" | "other";
  height?: number;
  weight?: number;
  bio?: string;
  createdAt: Date;
  updatedAt: Date;
}

// Define schema with <Schema<IUser, Model<IUser>, IUserMethods>>
const UserSchema = new Schema<IUser, Model<IUser>, IUserMethods>({
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

// Password hash middleware
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

// Custom method
UserSchema.methods.comparePassword = async function (
  candidatePassword: string
) {
  return bcrypt.compare(candidatePassword, this.password);
};

const User = mongoose.model<IUser>("User", UserSchema);
export default User;
