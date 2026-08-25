import "dotenv/config";
import "./models/index";
import express from "express";
import cors from "cors";
import AuthRoutes from "./routes/auth-routes";
import MemberRoutes from "./routes/member-routes";
import AdminRoutes from "./routes/admin-routes";
import TrainerRoutes from "./routes/trainer-routes";
import { apiKeyAuth } from "./middleware/apiKeyAuth";
import {
  morganLogger,
  responseBodyInterceptor,
} from "./middleware/logger-morgan";

const app = express();

// Middleware
app.use(express.json());
const allowedOrigins = (process.env.CORS_ORIGINS ||
  "http://localhost:3000,http://localhost:62217")
  .split(",")
  .map((origin) => origin.trim());
app.use(cors({ origin: allowedOrigins }));

app.use(responseBodyInterceptor); // This must be used before using morganLogger
app.use(morganLogger);
app.get("/health", (_req, res) => {
  res.status(200).json({ status: "ok" });
});

app.use(apiKeyAuth);
// API routes
app.use("/auth", AuthRoutes);
app.use("/member", MemberRoutes);
app.use("/admin", AdminRoutes);
app.use("/trainer", TrainerRoutes);

export default app;
