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

export function renewalWindow(
  requestedStartMillis: number,
  currentEndMillis: number | null,
  durationDays: number
): { startsAtMillis: number; endsAtMillis: number } {
  if (!Number.isInteger(durationDays) || durationDays < 1 || durationDays > 3660) {
    throw new Error("Membership duration must be between 1 and 3660 days.");
  }
  const startsAtMillis = currentEndMillis !== null && currentEndMillis > requestedStartMillis
    ? currentEndMillis
    : requestedStartMillis;
  return {
    startsAtMillis,
    endsAtMillis: startsAtMillis + durationDays * 86400000
  };
}

export function expiryReminderWindow(daysRemaining: number): 0 | 1 | 3 | 7 {
  if (daysRemaining <= 0) return 0;
  if (daysRemaining <= 1) return 1;
  if (daysRemaining <= 3) return 3;
  return 7;
}
