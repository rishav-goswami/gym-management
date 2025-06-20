import { Request, Response, NextFunction } from "express";
import { AUTH_KEY } from "../constants/auth";
import crypto from "crypto";

// ...existing code...

export function apiKeyAuth(req: Request, res: Response, next: NextFunction) {
  const expectedKey = process.env.AUTH_KEY;
  const receivedKey =
    (req.headers[AUTH_KEY.toLowerCase()] as string) ||
    (req.headers["x-api-key"] as string);

  if (
    !expectedKey ||
    !receivedKey ||
    !crypto.timingSafeEqual(
      Buffer.from(receivedKey),
      Buffer.from(expectedKey)
    )
  ) {
    res.status(401).json({ message: "Invalid or missing API key" });
    return;
  }
  next();
}