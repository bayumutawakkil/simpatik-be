import request from "supertest";
import { app } from "../src/app";

describe("auth", () => {
  it("login success", async () => {
    const r = await request(app).post("/api/auth/login").send({ email: process.env.SEED_ADMIN_EMAIL, password: process.env.SEED_ADMIN_PASSWORD });
    expect(r.status).toBe(200);
    expect(r.body.success).toBe(true);
  });
  it("login fail", async () => {
    const r = await request(app).post("/api/auth/login").send({ email: "x@x.com", password: "wrong" });
    expect(r.status).toBe(401);
  });
});
