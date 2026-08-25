import "dotenv/config";
import mongoose from "mongoose";
import app from "./server";
import MongoConnection from "./database/mongo_connect";

const PORT = process.env.PORT || 3002;
async function startServer() {
  const db = await MongoConnection.getInstance().connect();
  console.log("All data will be saved to the database:", db.name);

  const server = app.listen(PORT, () => {
    console.log(`> Ready on http://localhost:${PORT}`);
  });

  const shutdown = async (signal: string) => {
    console.log(`${signal} received; shutting down`);
    server.close(async () => {
      await mongoose.disconnect();
      process.exit(0);
    });
  };

  process.on("SIGTERM", () => void shutdown("SIGTERM"));
  process.on("SIGINT", () => void shutdown("SIGINT"));
}

startServer().catch((error) => {
  console.error("Failed to start server", error);
  process.exit(1);
});
