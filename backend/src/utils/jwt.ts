import jwt, { JwtPayload } from "jsonwebtoken";
import { JWT_SECRET, JWT_EXPIRES_IN } from "../constants/auth";

interface TokenPayload {
  id: string;
  email: string;
  role: string;
  [key: string]: any; // optional for extensibility
}

export function signJwt(payload: TokenPayload): string {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
}

export function verifyJwt(token: string): TokenPayload | null {
  try {
    return jwt.verify(token, JWT_SECRET) as TokenPayload;
  } catch (err) {
    return null;
  }
}
