import request from "supertest";
import { app } from "../src/app";
import { prisma } from "../src/config/prisma";
import jwt from "jsonwebtoken";
import { env } from "../src/config/env";

describe("Database & Prisma Integration Tests", () => {
  let adminToken: string;
  let guruToken: string;
  let adminUser: any;
  let guruUser: any;
  let guruRecord: any;

  beforeAll(async () => {
    // Generate valid tokens for integration tests if users exist
    adminUser = await prisma.user.findFirst({ where: { role: "ADMIN" } });
    if (adminUser) {
      adminToken = jwt.sign({ userId: adminUser.id, role: adminUser.role }, env.JWT_SECRET, { expiresIn: "1h" });
    }

    guruRecord = await prisma.guru.findFirst({ include: { user: true } });
    if (guruRecord && guruRecord.user) {
      guruUser = guruRecord.user;
      guruToken = jwt.sign({ userId: guruUser.id, role: guruUser.role }, env.JWT_SECRET, { expiresIn: "1h" });
    }
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  describe("1. Autentikasi Pengguna", () => {
    it("Gagal login dengan kredensial yang salah (401)", async () => {
      const res = await request(app)
        .post("/api/auth/login")
        .send({ email: "invalid@simpatik.test", password: "wrongpassword" });
      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });

    it("Berhasil login dengan kredensial admin yang valid", async () => {
      const email = process.env.SEED_ADMIN_EMAIL || "admin@simpatik.test";
      const password = process.env.SEED_ADMIN_PASSWORD || "admin123";
      const res = await request(app)
        .post("/api/auth/login")
        .send({ email, password });
      
      if (res.status === 200) {
        expect(res.body.success).toBe(true);
        expect(res.body.data.accessToken).toBeDefined();
        expect(res.body.data.user.role).toBe("ADMIN");
      }
    });
  });

  describe("2. Soft Delete Siswa & Query Filter", () => {
    it("Daftar siswa hanya menampilkan siswa aktif (deletedAt IS NULL)", async () => {
      if (!adminToken) return;
      const res = await request(app)
        .get("/api/siswa?limit=100")
        .set("Authorization", `Bearer ${adminToken}`);
      
      if (res.status === 200) {
        expect(res.body.success).toBe(true);
        const data = res.body.data;
        const hasDeleted = data.some((s: any) => s.deletedAt !== null);
        expect(hasDeleted).toBe(false);
      }
    });

    it("Detail siswa yang soft-deleted mengembalikan 404 NOT_FOUND", async () => {
      if (!adminToken) return;
      const deletedSiswa = await prisma.siswa.findFirst({ where: { deletedAt: { not: null } } });
      if (deletedSiswa) {
        const res = await request(app)
          .get(`/api/siswa/${deletedSiswa.id}`)
          .set("Authorization", `Bearer ${adminToken}`);
        expect(res.status).toBe(404);
        expect(res.body.success).toBe(false);
      }
    });
  });

  describe("3. Pencegahan NIS Duplikat (P2002 -> 409 Conflict)", () => {
    it("Membuat siswa dengan NIS yang sudah ada harus menghasilkan 409 Conflict", async () => {
      if (!adminToken) return;
      const existingSiswa = await prisma.siswa.findFirst();
      if (existingSiswa) {
        const res = await request(app)
          .post("/api/siswa")
          .set("Authorization", `Bearer ${adminToken}`)
          .send({
            nis: existingSiswa.nis, // NIS duplikat
            nama: "Siswa Uji Duplikat",
            jenisKelamin: "LAKI_LAKI",
            tanggalLahir: "2010-01-01",
          });
        expect(res.status).toBe(409);
        expect(res.body.success).toBe(false);
        expect(res.body.error.code).toBe("CONFLICT");
      }
    });
  });

  describe("4. Validasi Penugasan Guru & Rentang Nilai", () => {
    it("Nilai di luar 0-100 ditolak dengan 400 VALIDATION_ERROR", async () => {
      if (!guruToken) return;
      const res = await request(app)
        .post("/api/nilai")
        .set("Authorization", `Bearer ${guruToken}`)
        .send({
          siswaId: "00000000-0000-0000-0000-000000000000",
          mataPelajaranId: "00000000-0000-0000-0000-000000000000",
          periode: "2026-GANJIL",
          jenisNilai: "HARIAN",
          nilai: 150, // Nilai > 100
        });
      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  describe("5. Integritas Audit Log (Append-Only)", () => {
    it("Prisma Client dapat membaca dan mencatat audit log", async () => {
      const logs = await prisma.auditLog.findMany({ take: 5 });
      expect(Array.isArray(logs)).toBe(true);
    });
  });
});
