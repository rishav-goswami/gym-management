import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import { JWT_SECRET } from "../constants/auth";
import { ROLES } from "../constants/roles";
import { isTokenRevoked } from "../utils/revokeTokenStore";
import { verifyJwt } from "../utils/jwt";

export interface AuthRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: string;
    [key: string]: any;
  };
}

export async function jwtAuth(
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers["authorization"];

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    res.status(401).json({ message: "No token provided" });
    return;
  }

  const token = authHeader.split(" ")[1];

  try {
    const revoked = await isTokenRevoked(token);
    if (revoked) {
      res.status(401).json({ message: "Token has been revoked" });
      return;
    }

    const decoded = verifyJwt(token);
    if (!decoded) {
      res.status(401).json({ message: "Invalid or expired token" });
      return;
    }

    req.user = decoded;
    next();
  } catch (err) {
    res.status(500).json({ message: "Internal server error", error: err });
  }
}

export function requireRole(
  req: AuthRequest,
  res: Response,
  next: NextFunction,
  roles: string
) {
  if (!req.user || !roles.includes(req.user.role)) {
    return res.status(403).json({ message: "Forbidden: insufficient role" });
  }
  next();
}
