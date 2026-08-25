import "dotenv/config";
import mongoose from "mongoose";
import { z } from "zod";
import MongoConnection from "../database/mongo_connect";
import Admin from "../models/admin";

const adminInputSchema = z.object({
  name: z.string().min(2),
  email: z.string().email().transform((email) => email.toLowerCase()),
  password: z.string().min(12),
});

async function createAdmin() {
  const input = adminInputSchema.parse({
    name: process.env.ADMIN_NAME,
    email: process.env.ADMIN_EMAIL,
    password: process.env.ADMIN_PASSWORD,
  });

  await MongoConnection.getInstance().connect();

  const existingAdmin = await Admin.findOne({ email: input.email });
  if (existingAdmin) {
    console.log(`Admin already exists: ${input.email}`);
    return;
  }

  await Admin.create(input);
  console.log(`Admin created: ${input.email}`);
}

createAdmin()
  .catch((error) => {
    console.error("Unable to create admin", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
