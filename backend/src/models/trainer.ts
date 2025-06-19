import mongoose, { Document, Schema, ObjectId } from "mongoose";

interface Trainer {
  _id: ObjectId;
  name: string;
  email: string;
  password: string;
  assignedUsers: ObjectId[];
  profileImage?: string;
  createdAt: Date;
  updatedAt: Date;
}

const TrainerSchema = new Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  assignedUsers: [{ type: Schema.Types.ObjectId, ref: 'User' }],
  profileImage: { type: String },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

const Trainer = mongoose.model('Trainer', TrainerSchema);
export default Trainer;
