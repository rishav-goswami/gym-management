import mongoose, { Schema, Document, ObjectId } from 'mongoose';

export interface IRevokedToken extends Document {
  token: string;
  userId?: ObjectId;
  revokedAt: Date;
}

const RevokedTokenSchema = new Schema<IRevokedToken>({
  token: { type: String, required: true, unique: true },
  userId: { type: Schema.Types.ObjectId, ref: 'User' },
  revokedAt: { type: Date, default: Date.now },
});

const RevokedToken = mongoose.model<IRevokedToken>('RevokedToken', RevokedTokenSchema);
export default RevokedToken;
