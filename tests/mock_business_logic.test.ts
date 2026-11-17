import request from "supertest";
import jwt from "jsonwebtoken";
import { app } from "../src/app";
import { prisma } from "../src/config/prisma";
import { env } from "../src/config/env";
import { Prisma } from "@prisma/client";

// Mock prisma secara modular
jest.mock("../src/config/prisma", () => ({
  prisma: {
    user: {
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    guru: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
    },
    siswa: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
    },
    kelas: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
    },
    mataPelajaran: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
    },
    nilai: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    prestasi: {
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    auditLog: {
      findMany: jest.fn(),
      create: jest.fn(),
    },
    $disconnect: jest.fn(),
  },
}));

describe("Core Business Logic with Prisma Mocks", () => {
  const adminId = "admin-uuid-123";
  const guruId = "guru-uuid-456";
  const mockAdminUser = {
    id: adminId,
    name: "Mock Admin",
    email: "admin@mock.test",
    role: "ADMIN",
    isActive: true,
  };
  const mockGuruUser = {
    id: guruId,
    name: "Mock Guru",
    email: "guru@mock.test",
    role: "GURU",
    isActive: true,
  };

  const adminToken = jwt.sign({ userId: adminId, role: "ADMIN" }, env.JWT_SECRET, { expiresIn: "1h" });
  const guruToken = jwt.sign({ userId: guruId, role: "GURU" }, env.JWT_SECRET, { expiresIn: "1h" });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("Siswa Business Logic (Mocked)", () => {
    it("mengembalikan daftar siswa yang aktif (deletedAt: null)", async () => {
      (prisma.user.findUnique as jest.Mock).mockResolvedValue(mockAdminUser);
      (prisma.siswa.findMany as jest.Mock).mockResolvedValue([
        { id: "s-1", nis: "1001", nama: "Siswa A", deletedAt: null },
        { id: "s-2", nis: "1002", nama: "Siswa B", deletedAt: null },
      ]);
      (prisma.siswa.count as jest.Mock).mockResolvedValue(2);

      const res = await request(app)
        .get("/api/siswa")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(2);
      expect(prisma.siswa.findMany).toHaveBeenCalled();
    });

    it("menolak akses manajemen siswa tanpa token (401)", async () => {
      const res = await request(app).get("/api/siswa");
      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });

    it("menangani konflik unik saat membuat siswa dengan NIS duplikat (409)", async () => {
      (prisma.user.findUnique as jest.Mock).mockResolvedValue(mockAdminUser);
      (prisma.siswa.create as jest.Mock).mockRejectedValue(
        new Prisma.PrismaClientKnownRequestError("Unique constraint failed", {
          code: "P2002",
          clientVersion: "5.22.0",
          meta: { target: ["nis"] },
        })
      );

      const res = await request(app)
        .post("/api/siswa")
        .set("Authorization", `Bearer ${adminToken}`)
        .send({
          nis: "1001",
          nama: "Siswa Duplikat",
          jenisKelamin: "LAKI_LAKI",
          tanggalLahir: "2010-01-01",
        });

      expect(res.status).toBe(409);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe("CONFLICT");
    });
  });

  describe("Kelas & Akademik Logic (Mocked)", () => {
    it("mengembalikan daftar kelas untuk admin", async () => {
      (prisma.user.findUnique as jest.Mock).mockResolvedValue(mockAdminUser);
      (prisma.kelas.findMany as jest.Mock).mockResolvedValue([
        { id: "k-1", nama: "VII-A", tingkat: "7", tahunAjaran: "2026/2027" },
      ]);

      const res = await request(app)
        .get("/api/kelas")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(1);
    });
  });

  describe("Nilai Logic (Mocked)", () => {
    it("menolak input nilai dengan format di luar batas 0-100", async () => {
      (prisma.user.findUnique as jest.Mock).mockResolvedValue(mockGuruUser);

      const res = await request(app)
        .post("/api/nilai")
        .set("Authorization", `Bearer ${guruToken}`)
        .send({
          siswaId: "some-siswa-id",
          mataPelajaranId: "some-mapel-id",
          periode: "2026-GANJIL",
          jenisNilai: "HARIAN",
          nilai: -10, // nilai negatif tidak valid
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    it("menolak pencatatan nilai jika siswa tidak ditemukan (404)", async () => {
      (prisma.user.findUnique as jest.Mock).mockResolvedValue(mockAdminUser);
      (prisma.siswa.findUnique as jest.Mock).mockResolvedValue(null);

      const res = await request(app)
        .post("/api/nilai")
        .set("Authorization", `Bearer ${adminToken}`)
        .send({
          siswaId: "non-existent-siswa",
          mataPelajaranId: "some-mapel-id",
          periode: "2026-GANJIL",
          jenisNilai: "HARIAN",
          nilai: 95,
        });

      expect(res.status).toBe(404);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe("NOT_FOUND");
    });
  });
});
