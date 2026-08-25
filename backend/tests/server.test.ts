import request from "supertest";
import { beforeAll, describe, expect, it } from "@jest/globals";
import app from "../src/server";

const apiKey = "test-api-key";

describe("API server", () => {
  beforeAll(() => {
    process.env.AUTH_KEY = apiKey;
  });

  it("exposes a public health check", async () => {
    const response = await request(app).get("/health");

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: "ok" });
  });

  it("rejects protected API calls without an API key", async () => {
    const response = await request(app).post("/auth/login").send({});

    expect(response.status).toBe(401);
    expect(response.body.message).toBe("Invalid or missing API key");
  });

  it("rejects API keys of a different length without throwing", async () => {
    const response = await request(app)
      .post("/auth/login")
      .set("x-api-key", "x")
      .send({});

    expect(response.status).toBe(401);
  });

  it("validates an auth request before accessing MongoDB", async () => {
    const response = await request(app)
      .post("/auth/login")
      .set("x-api-key", apiKey)
      .send({ email: "not-an-email", password: "short", role: "MEMBER" });

    expect(response.status).toBe(400);
    expect(response.body.success).toBe(false);
    expect(response.body.errors).toEqual(expect.any(Array));
  });

  it("requires a bearer token for member routes", async () => {
    const response = await request(app)
      .get("/member/me")
      .set("x-api-key", apiKey);

    expect(response.status).toBe(401);
    expect(response.body.message).toBe("No token provided");
  });
});
