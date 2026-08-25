import mongoose from "mongoose";
import { config } from "dotenv";
config();

class MongoConnection {
  private static instance: MongoConnection;
  private readonly db: mongoose.Connection;
  private readonly mongoUri: string;

  private constructor() {
    this.mongoUri =
      process.env.MONGO_URI || "mongodb://localhost:27017/fitness-app";
    this.db = mongoose.connection;
  }

  public static getInstance(): MongoConnection {
    if (!MongoConnection.instance) {
      MongoConnection.instance = new MongoConnection();
    }
    return MongoConnection.instance;
  }

  public async connect(): Promise<mongoose.Connection> {
    if (this.db.readyState === 0) {
      await mongoose.connect(this.mongoUri);
    }
    return this.db;
  }
}

export default MongoConnection;
