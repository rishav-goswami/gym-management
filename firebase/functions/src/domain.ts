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

export function canSelfServiceReactivateMembership(status: unknown): boolean {
  return status === "left";
}

export function attendanceDocumentId(uid: string, dateKey: string): string {
  return `${dateKey}_${uid}`;
}

export function bookingDocumentId(sessionId: string, uid: string): string {
  return `${sessionId}_${uid}`;
}

export const GYM_SUPPORT_CATEGORIES = [
  "coaching",
  "membership",
  "payment",
  "attendance",
  "classes",
  "facility",
  "other"
] as const;

export type GymSupportCategory = typeof GYM_SUPPORT_CATEGORIES[number];

export function supportPermissionForCategory(category: GymSupportCategory): string {
  if (category === "coaching") return "support.coaching";
  if (category === "payment") return "support.billing";
  return "support.manage";
}

export function supportRetentionMillis(resolvedAtMillis: number): number {
  return resolvedAtMillis + 365 * 24 * 60 * 60 * 1000;
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

export const USAGE_FIELDS = [
  "activeMembers",
  "activeTrainers",
  "activeStaff",
  "scheduledClasses"
] as const;

export type UsageField = typeof USAGE_FIELDS[number];

export function usageFieldForRole(role: string): UsageField | null {
  if (role === "member") return "activeMembers";
  if (role === "trainer") return "activeTrainers";
  if (["manager", "receptionist", "accountant"].includes(role)) return "activeStaff";
  return null;
}

export function assertWithinLimit(
  field: UsageField,
  current: number,
  change: number,
  limits: Record<string, unknown>
): number {
  const next = Math.max(0, current + change);
  const rawLimit = limits[field];
  const limit = typeof rawLimit === "number" ? rawLimit : 0;
  if (!Number.isInteger(limit) || limit < 0) {
    throw new Error(`Invalid entitlement limit: ${field}`);
  }
  if (next > limit) {
    throw new Error(`LIMIT_EXCEEDED:${field}:${current}:${limit}`);
  }
  return next;
}
