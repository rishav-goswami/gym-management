import mongoose, { Document, Schema, Model, Types } from "mongoose";
import bcrypt from "bcryptjs";

// Custom instance method interface
interface ITrainerMethods {
  comparePassword(candidatePassword: string): Promise<boolean>;
}

// Full document interface with methods
export interface ITrainer extends Document, ITrainerMethods {
  _id: Types.ObjectId;
  name: string;
  email: string;
  password: string;
  assignedUsers: Types.ObjectId[];
  profileImage?: string;
  verified: Boolean;
  createdAt: Date;
  updatedAt: Date;
}

// Schema with proper generics
const TrainerSchema = new Schema<ITrainer, Model<ITrainer>, ITrainerMethods>({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  assignedUsers: [{ type: Schema.Types.ObjectId, ref: "User" }],
  profileImage: { type: String },
  verified: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

// Hash password before saving
TrainerSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (err) {
    next(err as Error);
  }
});

// Instance method to compare passwords
TrainerSchema.methods.comparePassword = async function (
  candidatePassword: string
): Promise<boolean> {
  return bcrypt.compare(candidatePassword, this.password);
};

// Export model
const Trainer = mongoose.model<ITrainer>("Trainer", TrainerSchema);
export default Trainer;
