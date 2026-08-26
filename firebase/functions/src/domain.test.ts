import { describe, expect, it } from "vitest";
import {
  attendanceDocumentId,
  bookingDocumentId,
  hashToken,
  membershipDocumentId,
  normalizeEmail,
  normalizePhone,
  secureToken
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
});
