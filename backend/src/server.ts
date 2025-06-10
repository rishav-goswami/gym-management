import express from "express";
import MongoConnection from "./database/mongo_connect";
import { createServer } from "http";
import cors from "cors";
import morgan from "morgan";
import AuthRoutes from "./routes/auth-routes";


// connecting to database
(async () => {
  const db = await MongoConnection.getInstance().getDb();
  console.log("All data will be saved to the database:", db.name);
})();

const app = express();
const server = createServer(app);

// Middleware
app.use(express.json());
app.use(cors({ origin: ["http://localhost:3000"] }));
app.use(morgan("dev"));

// API routes
app.use("/auth", AuthRoutes);


export default server;
