import { createHash, randomBytes } from "node:crypto";

export function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

export function normalizePhone(value: string): string {
  return value.replace(/[^+\d]/g, "");
}

export function secureToken(bytes = 32): string {
  return randomBytes(bytes).toString("base64url");
}

export function hashToken(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export function membershipDocumentId(gymId: string, uid: string): string {
  return `${gymId}_${uid}`;
}

export function attendanceDocumentId(uid: string, dateKey: string): string {
  return `${dateKey}_${uid}`;
}

export function bookingDocumentId(sessionId: string, uid: string): string {
  return `${sessionId}_${uid}`;
}
