import mongoose, { Document, Schema, ObjectId } from "mongoose";

interface IDietPlan extends Document {
  _id: ObjectId;
  userId: ObjectId;
  dayWiseDiet: [
    {
      day: string;
      meals: string[];
    }
  ];
  createdBy: ObjectId;
  createdAt: Date;
}

const DietPlanSchema = new Schema({
  userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
  dayWiseDiet: [
    {
      day: { type: String, required: true },
      meals: [{ type: String, required: true }],
    },
  ],
  createdBy: { type: Schema.Types.ObjectId, ref: "Trainer", required: true },
  createdAt: { type: Date, default: Date.now },
});

const DietPlan = mongoose.model<IDietPlan>("DietPlan", DietPlanSchema);
export default DietPlan;
