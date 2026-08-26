import { describe, expect, it } from "vitest";
import {
  attendanceDocumentId,
  assertWithinLimit,
  bookingDocumentId,
  expiryReminderWindow,
  hashToken,
  membershipDocumentId,
  normalizeEmail,
  normalizePhone,
  renewalWindow,
  secureToken,
  usageFieldForRole
} from "./domain";

describe("tenant domain identifiers", () => {
  it("normalizes invitation identities", () => {
    expect(normalizeEmail(" Admin@Example.COM ")).toBe("admin@example.com");
    expect(normalizePhone("+91 98765-43210")).toBe("+919876543210");
  });

  it("creates deterministic scoped document ids", () => {
    expect(membershipDocumentId("gym-a", "user-1")).toBe("gym-a_user-1");
    expect(attendanceDocumentId("user-1", "2026-08-25")).toBe("2026-08-25_user-1");
    expect(bookingDocumentId("morning-yoga", "user-1")).toBe("morning-yoga_user-1");
  });

  it("never stores the invitation or QR secret in plaintext", () => {
    const token = secureToken();
    expect(token.length).toBeGreaterThan(30);
    expect(hashToken(token)).toMatch(/^[a-f0-9]{64}$/);
    expect(hashToken(token)).not.toContain(token);
  });

  it("extends an active subscription without overlapping its current period", () => {
    const now = Date.UTC(2026, 7, 26);
    const currentEnd = Date.UTC(2026, 8, 15);
    expect(renewalWindow(now, currentEnd, 30)).toEqual({
      startsAtMillis: currentEnd,
      endsAtMillis: currentEnd + 30 * 86400000
    });
    expect(renewalWindow(now, now - 1, 30)).toEqual({
      startsAtMillis: now,
      endsAtMillis: now + 30 * 86400000
    });
  });

  it("buckets expiry reminders for deduplicated 7, 3, 1 and expiry messages", () => {
    expect([8, 7, 4, 3, 2, 1, 0].map(expiryReminderWindow)).toEqual([
      7, 7, 7, 3, 3, 1, 0
    ]);
  });
});

describe("SaaS quota enforcement", () => {
  it("maps tenant roles to independently enforced usage counters", () => {
    expect(usageFieldForRole("member")).toBe("activeMembers");
    expect(usageFieldForRole("trainer")).toBe("activeTrainers");
    expect(usageFieldForRole("manager")).toBe("activeStaff");
    expect(usageFieldForRole("owner")).toBeNull();
  });

  it("allows capacity and rejects the first unit above a plan limit", () => {
    const limits = { activeMembers: 5 };
    expect(assertWithinLimit("activeMembers", 4, 1, limits)).toBe(5);
    expect(() => assertWithinLimit("activeMembers", 5, 1, limits))
      .toThrow("LIMIT_EXCEEDED:activeMembers:5:5");
  });

  it("never lets usage counters become negative", () => {
    expect(assertWithinLimit("activeTrainers", 0, -1, { activeTrainers: 1 })).toBe(0);
  });
});
