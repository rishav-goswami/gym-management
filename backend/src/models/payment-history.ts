import mongoose, { Document, Schema, ObjectId } from "mongoose";

interface IPaymentHistory extends Document {
  _id: ObjectId;
  userId: ObjectId;
  amount: number;
  method: "UPI" | "Card" | "Cash";
  date: Date;
  remarks?: string;
}

const PaymentHistorySchema = new Schema({
  userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
  amount: { type: Number, required: true },
  method: { type: String, enum: ["UPI", "Card", "Cash"], required: true },
  date: { type: Date, required: true },
  remarks: { type: String },
});

const PaymentHistory = mongoose.model<IPaymentHistory>(
  "PaymentHistory",
  PaymentHistorySchema
);
export default PaymentHistory;
