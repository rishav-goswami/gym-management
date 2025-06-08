import mongoose from "mongoose";
import { config } from "dotenv";
config();

class MongoConnection {
  private static instance: MongoConnection;
  private db: mongoose.Connection;

  private constructor() {
    const mongoUri =
      process.env.MONGO_URI || "mongodb://localhost:27017/fitness-app";
    mongoose.connect(mongoUri, {});

    this.db = mongoose.connection;
    this.db.on(
      "error",
      console.error.bind(console, "MongoDB connection error:")
    );
    this.db.once("open", () => {
      console.log("MongoDB connected successfully");
    });
  }

  public static getInstance(): MongoConnection {
    if (!MongoConnection.instance) {
      MongoConnection.instance = new MongoConnection();
    }
    return MongoConnection.instance;
  }

  public getDb(): mongoose.Connection {
    return this.db;
  }
}

export default MongoConnection;
