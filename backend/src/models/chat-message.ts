import mongoose, { Document, Schema, ObjectId} from "mongoose";

interface ChatMessage {
  _id: ObjectId,
  from: ObjectId,
  to: ObjectId,
  message: string,
  timestamp: Date,
  read: boolean
}

const ChatMessageSchema = new Schema({
  from: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  to: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  message: { type: String, required: true },
  timestamp: { type: Date, default: Date.now },
  read: { type: Boolean, default: false },
});

const ChatMessage = mongoose.model('ChatMessage', ChatMessageSchema);
export default ChatMessage;