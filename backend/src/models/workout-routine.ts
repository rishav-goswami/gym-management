import mongoose, { Document, Schema, ObjectId } from "mongoose";

interface WorkoutRoutine {
  _id: ObjectId;
  userId: ObjectId;
  days: [
    {
      day: string;
      exercises: string[];
    }
  ];
  createdBy: ObjectId;
  createdAt: Date;
}

const WorkoutRoutineSchema = new Schema({
  userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  days: [
    {
      day: { type: String, required: true },
      exercises: [{ type: String, required: true }],
    }
  ],
  createdBy: { type: Schema.Types.ObjectId, ref: 'Trainer', required: true },
  createdAt: { type: Date, default: Date.now },
});

const WorkoutRoutine = mongoose.model('WorkoutRoutine', WorkoutRoutineSchema);
export default WorkoutRoutine;
