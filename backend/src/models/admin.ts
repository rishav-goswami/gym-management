import mongoose, { Document, Schema, Model, Types } from "mongoose";
import bcrypt from "bcryptjs";

// Custom instance method interface
interface IAdminMethods {
  comparePassword(candidatePassword: string): Promise<boolean>;
}

// Full document interface including custom methods
export interface IAdmin extends Document, IAdminMethods {
  _id: Types.ObjectId;
  name: string;
  email: string;
  password: string;
  profileImage: string;
  createdAt: Date;
  updatedAt: Date;
}

// Define schema with generics: <IAdmin, Model<IAdmin>, IAdminMethods>
const AdminSchema = new Schema<IAdmin, Model<IAdmin>, IAdminMethods>({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  profileImage: { type: String },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

// Hash password before saving
AdminSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (err) {
    next(err as Error);
  }
});

// Add method to compare password
AdminSchema.methods.comparePassword = async function (
  candidatePassword: string
): Promise<boolean> {
  return bcrypt.compare(candidatePassword, this.password);
};

// Create model
const Admin = mongoose.model<IAdmin>("Admin", AdminSchema);
export default Admin;
