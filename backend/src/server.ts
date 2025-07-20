import "./models/index";
import express from "express";
import MongoConnection from "./database/mongo_connect";
import { createServer } from "http";
import cors from "cors";
import morgan from "morgan";
import AuthRoutes from "./routes/auth-routes";
import MemberRoutes from "./routes/member-routes";
import AdminRoutes from "./routes/admin-routes";
import TrainerRoutes from "./routes/trainer-routes";
import { apiKeyAuth } from "./middleware/apiKeyAuth";
import {
  morganLogger,
  responseBodyInterceptor,
} from "./middleware/logger-morgan";

// connecting to database
(async () => {
  const db = await MongoConnection.getInstance().getDb();
  console.log("All data will be saved to the database:", db.name);
})();

const app = express();
const server = createServer(app);

// Middleware
app.use(express.json());
app.use(cors({ origin: ["http://localhost:3000", "http://localhost:62217"] }));

app.use(responseBodyInterceptor); // This must be used before using morganLogger
app.use(morganLogger);
// app.use(morgan("dev"));
app.use(apiKeyAuth);
// API routes
app.use("/auth", AuthRoutes);
app.use("/member", MemberRoutes);
app.use("/admin", AdminRoutes);
app.use("/trainer", TrainerRoutes);

export default server;
