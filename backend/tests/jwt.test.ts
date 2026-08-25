import { describe, expect, it } from "@jest/globals";
import { signJwt, verifyJwt } from "../src/utils/jwt";

describe("JWT utilities", () => {
  it("signs and verifies an authenticated user payload", () => {
    const payload = {
      id: "member-id",
      email: "member@example.com",
      role: "MEMBER",
    };

    const token = signJwt(payload);

    expect(verifyJwt(token)).toEqual(expect.objectContaining(payload));
  });

  it("returns null for an invalid token", () => {
    expect(verifyJwt("not-a-jwt")).toBeNull();
  });
});
