import { Schema } from "mongoose";
interface Subscription {
  isActive: boolean,
  startDate: Date,
  endDate: Date,
  paymentMethod: 'UPI' | 'Card' | 'Cash',
  amountPaid: number
}

export const SubscriptionSchema = new Schema({
  isActive: { type: Boolean, required: true },
  startDate: { type: Date, required: true },
  endDate: { type: Date, required: true },
  paymentMethod: { type: String, enum: ['UPI', 'Card', 'Cash'], required: true },
  amountPaid: { type: Number, required: true },
});