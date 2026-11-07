import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import multer from "multer";
import path from "path";
import fs from "fs";
import { env } from "./config/env";
import { prisma } from "./config/prisma";
import { handlePrismaError, AppError } from "./utils/prismaError";
import { USER_PUBLIC_SELECT, passwordPolicyError, loginLimiter, resolveUploadPath } from "./security";

export const app = express();
app.use(helmet());
const allowedOrigins = env.CORS_ORIGIN === "*"
  ? true
  : env.CORS_ORIGIN.split(",").map((s) => s.trim());

app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins === true || (Array.isArray(allowedOrigins) && allowedOrigins.includes(origin))) {
      callback(null, true);
    } else {
      callback(null, true);
    }
  },
  credentials: true,
}));
app.use(morgan("dev"));
app.use(express.json({ limit: "100kb" }));

// Global async wrapper to prevent unhandled promise rejections from crashing the server
const wrapHandler = (h: any): any => {
  if (Array.isArray(h)) return h.map(wrapHandler);
  if (typeof h !== "function") return h;
  if (h.length === 4) return h; // Skip Express error middleware
  return (req: any, res: any, next: any) => {
    try {
      const result = h(req, res, next);
      if (result && typeof result.catch === "function") {
        result.catch(next);
      }
      return result;
    } catch (syncErr) {
      next(syncErr);
    }
  };
};

const methods = ["get", "post", "put", "patch", "delete"] as const;
for (const method of methods) {
  const original = (app as any)[method].bind(app);
  (app as any)[method] = (path: any, ...handlers: any[]) => {
    return original(path, ...handlers.map(wrapHandler));
  };
}

// ---------- helpers ----------
function ok(res: any, data: any, message?: string, meta?: any) {
  const body: any = { success: true, data };
  if (message) body.message = message;
  if (meta) body.meta = meta;
  res.json(body);
}

function fail(res: any, status: number, code: string, message: string, details?: any) {
  res.status(status).json({ success: false, error: { code, message, details } });
}

function sendError(res: any, err: unknown) {
  const appErr = handlePrismaError(err);
  fail(res, appErr.statusCode, appErr.errorCode, appErr.message, appErr.details);
}

function authMiddleware(req: any, res: any, next: any) {
  const h = req.headers.authorization;
  if (!h || !h.startsWith("Bearer ")) return fail(res, 401, "UNAUTHORIZED", "Token tidak ditemukan");
  try {
    const payload: any = jwt.verify(h.slice(7), env.JWT_SECRET);
    if (payload?.userId) {
      prisma.user.findUnique({ where: { id: String(payload.userId) } }).then((u) => {
        if (!u || !u.isActive) return fail(res, 401, "UNAUTHORIZED", "Akun tidak aktif");
        req.user = u;
        if (u.role === "KEPSEK") {
          const isPasswordChange = req.method === "PUT" && req.path === "/api/auth/change-password";
          const isAllowedRead = req.method === "GET" && /^\/api\/(guru|siswa|nilai|prestasi)(\/|$)/.test(req.path);
          if (!isPasswordChange && !isAllowedRead && req.path !== "/api/auth/me") {
            return fail(res, 403, "FORBIDDEN", "Kepala sekolah hanya memiliki akses baca data guru, siswa, nilai, dan prestasi");
          }
        }
        next();
      }).catch(() => fail(res, 401, "UNAUTHORIZED", "Token invalid"));
    } else fail(res, 401, "UNAUTHORIZED", "Token invalid");
  } catch {
    fail(res, 401, "UNAUTHORIZED", "Token invalid");
  }
}

function requireRole(...roles: string[]) {
  return (req: any, res: any, next: any) => {
    if (!req.user || !roles.includes(req.user.role)) return fail(res, 403, "FORBIDDEN", "Akses ditolak");
    next();
  };
}

// guru ownership check helper
async function guruForUser(userId: string) {
  return prisma.guru.findUnique({ where: { userId } });
}

async function isGuruOwnerOfSiswa(guruId: string, siswaId: string) {
  const s = await prisma.siswa.findUnique({ where: { id: siswaId }, include: { kelas: true } });
  if (!s || !s.kelasId) return false;
  const [guru, pen] = await Promise.all([
    prisma.guru.findUnique({ where: { id: guruId }, select: { kelasWali: { where: { id: s.kelasId }, select: { id: true } } } }),
    prisma.penugasanGuru.findFirst({ where: { guruId, OR: [{ kelasId: s.kelasId }, { kelasId: null }] } }),
  ]);
  return Boolean(guru?.kelasWali.length || pen);
}

async function hasPenugasan(guruId: string, kelasId: string, mapelId: string) {
  const [guru, pen] = await Promise.all([
    prisma.guru.findUnique({ where: { id: guruId, kelasWali: { some: { id: kelasId } } }, select: { id: true } }),
    prisma.penugasanGuru.findFirst({ where: { guruId, mataPelajaranId: mapelId, OR: [{ kelasId }, { kelasId: null }] } }),
  ]);
  return Boolean(guru || pen);
}

type GuruScope = { guruId: string; kelasIds: string[] | "all" };

async function guruClassScope(userId: string): Promise<GuruScope | null> {
  const g = await guruForUser(userId);
  if (!g) return null;
  const [pens, wali] = await Promise.all([
    prisma.penugasanGuru.findMany({ where: { guruId: g.id }, select: { kelasId: true } }),
    prisma.kelas.findMany({ where: { waliKelasId: g.id }, select: { id: true } }),
  ]);
  if (pens.some((p) => p.kelasId === null)) return { guruId: g.id, kelasIds: "all" };
  const kelasIds = [...new Set([...pens.flatMap((p) => (p.kelasId ? [p.kelasId] : [])), ...wali.map((k) => k.id)])];
  return { guruId: g.id, kelasIds };
}

async function applyGuruSiswaScope(user: { id: string; role: string }, where: any, kelasId?: string) {
  if (user.role !== "GURU") {
    if (kelasId) where.kelasId = kelasId;
    return { ok: true as const };
  }
  const scope = await guruClassScope(user.id);
  if (!scope) return { ok: false as const, status: 403, message: "Profil guru tidak ditemukan" };
  if (scope.kelasIds === "all") {
    if (kelasId) where.kelasId = kelasId;
    return { ok: true as const };
  }
  if (kelasId) {
    if (!scope.kelasIds.includes(kelasId)) return { ok: false as const, status: 403, message: "Bukan tanggung jawab Anda" };
    where.kelasId = kelasId;
  } else {
    where.kelasId = { in: scope.kelasIds };
  }
  return { ok: true as const };
}

async function guruCanAccessSiswa(user: { id: string; role: string }, siswaId: string) {
  if (user.role !== "GURU") return true;
  const g = await guruForUser(user.id);
  if (!g) return false;
  return isGuruOwnerOfSiswa(g.id, siswaId);
}

// ---------- AUTH ----------
app.post("/api/auth/login", loginLimiter, async (req, res) => {
  const { email, password } = req.body || {};
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || !user.isActive) return fail(res, 401, "INVALID_CREDENTIALS", "Email atau password salah");
  const okp = await bcrypt.compare(password, user.passwordHash);
  if (!okp) return fail(res, 401, "INVALID_CREDENTIALS", "Email atau password salah");
  const token = jwt.sign({ userId: user.id, role: user.role }, env.JWT_SECRET, { expiresIn: env.JWT_EXPIRES_IN } as any);
  ok(res, { accessToken: token, user: { id: user.id, name: user.name, role: user.role } });
});

app.post("/api/auth/logout", authMiddleware, (_req, res) => ok(res, null, "Logout berhasil"));

app.get("/api/auth/me", authMiddleware, (req: any, res) => {
  ok(res, { id: req.user.id, name: req.user.name, role: req.user.role, email: req.user.email });
});

app.put("/api/auth/change-password", authMiddleware, async (req: any, res) => {
  const { oldPassword, newPassword } = req.body || {};
  if (!oldPassword || !newPassword) return fail(res, 400, "VALIDATION_ERROR", "Field wajib");
  if (newPassword.length < 8 || !/[a-zA-Z]/.test(newPassword) || !/[0-9]/.test(newPassword)) {
    return fail(res, 400, "VALIDATION_ERROR", "Password baru minimal 8 karakter, memuat huruf dan angka");
  }
  const u = await prisma.user.findUnique({ where: { id: req.user.id } });
  if (!u || !(await bcrypt.compare(oldPassword, u.passwordHash))) return fail(res, 400, "VALIDATION_ERROR", "Password lama salah");
  await prisma.user.update({ where: { id: u.id }, data: { passwordHash: await bcrypt.hash(newPassword, 10) } });
  ok(res, null, "Password berhasil diubah");
});

// ---------- USERS (admin) ----------
app.get("/api/users", authMiddleware, requireRole("ADMIN"), async (_req, res) => {
  const users = await prisma.user.findMany({ where: { role: { in: ["GURU", "KEPSEK"] } }, select: { id: true, name: true, email: true, role: true, isActive: true, createdAt: true } });
  ok(res, users);
});

app.post("/api/users", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const { name, email, password, role } = req.body || {};
  if (!name || !email || !password) return fail(res, 400, "VALIDATION_ERROR", "Field wajib");
  try {
    const u = await prisma.user.create({ data: { name, email, passwordHash: await bcrypt.hash(password, 10), role: role || "GURU" } });
    ok(res, { id: u.id, name: u.name, email: u.email, role: u.role }, "Created", undefined);
  } catch (err) {
    sendError(res, err);
  }
});

app.put("/api/users/:id", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const id = String(req.params.id);
  const { name, email, role } = req.body || {};
  try {
    const u = await prisma.user.update({ where: { id }, data: { name, email, role } });
    ok(res, { id: u.id, name: u.name, email: u.email, role: u.role });
  } catch (err) {
    sendError(res, err);
  }
});

app.patch("/api/users/:id/status", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const id = String(req.params.id);
  const { isActive } = req.body || {};
  try {
    const u = await prisma.user.update({ where: { id }, data: { isActive: !!isActive } });
    ok(res, { id: u.id, isActive: u.isActive });
  } catch (err) {
    sendError(res, err);
  }
});

app.post("/api/users/:id/reset-password", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const id = String(req.params.id);
  const { newPassword } = req.body || {};
  const pw = newPassword || "password123";
  try {
    await prisma.user.update({ where: { id }, data: { passwordHash: await bcrypt.hash(pw, 10) } });
    ok(res, null, "Password direset");
  } catch (err) {
    sendError(res, err);
  }
});

// ---------- KELAS ----------
app.get("/api/kelas", authMiddleware, async (_req, res) => {
  const list = await prisma.kelas.findMany({ where: { deletedAt: null }, include: { waliKelas: true } });
  ok(res, list);
});

app.get("/api/kelas/:id", authMiddleware, async (req, res) => {
  const k = await prisma.kelas.findUnique({ where: { id: String(req.params.id) }, include: { waliKelas: true, siswa: { where: { deletedAt: null } } } });
  if (!k) return fail(res, 404, "NOT_FOUND", "Kelas tidak ditemukan");
  ok(res, k);
});

app.post("/api/kelas", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const { nama, tingkat, tahunAjaran, waliKelasId } = req.body || {};
  try {
    const k = await prisma.kelas.create({ data: { nama, tingkat: Number(tingkat), tahunAjaran, waliKelasId: waliKelasId ? String(waliKelasId) : null } });
    ok(res, k);
  } catch (err) {
    sendError(res, err);
  }
});

app.put("/api/kelas/:id", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const id = String(req.params.id);
  const { nama, tingkat, tahunAjaran, waliKelasId } = req.body || {};
  try {
    const k = await prisma.kelas.update({
      where: { id },
      data: {
        nama,
        tingkat: tingkat ? Number(tingkat) : undefined,
        tahunAjaran,
        waliKelasId: waliKelasId !== undefined ? (waliKelasId ? String(waliKelasId) : null) : undefined,
      },
    });
    ok(res, k);
  } catch (err) {
    sendError(res, err);
  }
});

app.delete("/api/kelas/:id", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  try {
    await prisma.kelas.update({ where: { id: String(req.params.id) }, data: { deletedAt: new Date() } });
    ok(res, null, "Dihapus");
  } catch (err) {
    sendError(res, err);
  }
});

// ---------- MATA PELAJARAN ----------
app.get("/api/mata-pelajaran", authMiddleware, async (_req, res) => {
  ok(res, await prisma.mataPelajaran.findMany({ where: { deletedAt: null } }));
});

app.get("/api/mata-pelajaran/:id", authMiddleware, async (req, res) => {
  const m = await prisma.mataPelajaran.findUnique({ where: { id: String(req.params.id) } });
  if (!m || m.deletedAt) return fail(res, 404, "NOT_FOUND", "Tidak ditemukan");
  ok(res, m);
});

app.post("/api/mata-pelajaran", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const { kode, nama } = req.body || {};
  try {
    ok(res, await prisma.mataPelajaran.create({ data: { kode, nama } }));
  } catch (err) {
    sendError(res, err);
  }
});

app.put("/api/mata-pelajaran/:id", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const { kode, nama } = req.body || {};
  try {
    ok(res, await prisma.mataPelajaran.update({ where: { id: String(req.params.id) }, data: { kode, nama } }));
  } catch (err) {
    sendError(res, err);
  }
});

app.delete("/api/mata-pelajaran/:id", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  try {
    await prisma.mataPelajaran.update({ where: { id: String(req.params.id) }, data: { deletedAt: new Date() } });
    ok(res, null);
  } catch (err) {
    sendError(res, err);
  }
});

// ---------- GURU ----------
app.get("/api/guru", authMiddleware, async (req, res) => {
  const search = String(req.query.search || "");
  const page = Number(req.query.page || 1);
  const limit = Number(req.query.limit || 20);
  const where: any = { deletedAt: null };
  if (search) where.OR = [{ nama: { contains: search } }, { nip: { contains: search } }];
  const [total, data] = await Promise.all([
    prisma.guru.count({ where }),
    prisma.guru.findMany({ where, skip: (page - 1) * limit, take: limit, include: { penugasan: true } }),
  ]);
  ok(res, data, undefined, { page, limit, total, totalPages: Math.ceil(total / limit) });
});

app.get("/api/guru/:id", authMiddleware, async (req, res) => {
  const g = await prisma.guru.findUnique({
    where: { id: String(req.params.id) },
    include: { penugasan: { include: { kelas: true, mapel: true } }, user: true },
  });
  if (!g || g.deletedAt) return fail(res, 404, "NOT_FOUND", "Guru tidak ditemukan");
  ok(res, g);
});

app.post("/api/guru", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const { nip, nama, alamat, noTelepon, email, password } = req.body || {};
  let userId: string | undefined;
  if (email) {
    const u = await prisma.user.create({ data: { name: nama, email, passwordHash: await bcrypt.hash(password || "password123", 10), role: "GURU" } });
    userId = u.id;
  }
  try {
    const g = await prisma.guru.create({ data: { nip, nama, alamat, noTelepon, userId } });
    ok(res, g, "Created");
  } catch (err) {
    sendError(res, err);
  }
});

app.put("/api/guru/:id", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const { nip, nama, alamat, noTelepon } = req.body || {};
  try {
    const g = await prisma.guru.update({ where: { id: String(req.params.id) }, data: { nip, nama, alamat, noTelepon } });
    ok(res, g);
  } catch (err) {
    sendError(res, err);
  }
});

app.delete("/api/guru/:id", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const id = String(req.params.id);
  const g = await prisma.guru.findUnique({ where: { id }, include: { kelasWali: true, penugasan: true } });
  if (g?.kelasWali?.length || g?.penugasan?.length) {
    return fail(res, 422, "BUSINESS_RULE", "Guru masih memiliki penugasan aktif atau terdaftar sebagai wali kelas");
  }
  await prisma.guru.update({ where: { id }, data: { deletedAt: new Date() } });
  ok(res, null);
});

app.get("/api/guru/:id/penugasan", authMiddleware, async (req, res) => {
  ok(res, await prisma.penugasanGuru.findMany({ where: { guruId: String(req.params.id) }, include: { kelas: true, mapel: true } }));
});

app.put("/api/guru/:id/penugasan", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const guruId = String(req.params.id);
  const { penugasan } = req.body || {}; // array of {kelasId?: string|null, mataPelajaranId: string}
  await prisma.penugasanGuru.deleteMany({ where: { guruId } });
  if (Array.isArray(penugasan)) {
    for (const p of penugasan) {
      if (!p.mataPelajaranId) return fail(res, 400, "VALIDATION_ERROR", "Mata pelajaran wajib dipilih");
      await prisma.penugasanGuru.create({
        data: {
          guruId,
          kelasId: p.kelasId ? String(p.kelasId) : null,
          mataPelajaranId: String(p.mataPelajaranId),
        },
      });
    }
  }
  ok(res, await prisma.penugasanGuru.findMany({ where: { guruId } }));
});

// ---------- SISWA ----------
app.get("/api/siswa", authMiddleware, async (req: any, res) => {
  const page = Number(req.query.page || 1);
  const limit = Number(req.query.limit || 20);
  const search = String(req.query.search || req.query.q || "");
  const kelasId = req.query.kelasId ? String(req.query.kelasId) : undefined;
  const where: any = { deletedAt: null };
  if (search) where.OR = [{ nama: { contains: search } }, { nis: { contains: search } }];
  if (kelasId) where.kelasId = kelasId;

  // guru scoping
  if (req.user.role === "GURU") {
    const g = await guruForUser(req.user.id);
    if (!g) return fail(res, 403, "FORBIDDEN", "Profil guru tidak ditemukan untuk akun ini");
    const pens = await prisma.penugasanGuru.findMany({ where: { guruId: g.id } });
    const kelasIds = [...new Set(pens.map((p) => p.kelasId).filter((id): id is string => id !== null))];
    if (kelasId) {
      if (!kelasIds.includes(kelasId)) {
        return fail(res, 403, "FORBIDDEN", "Anda tidak memiliki akses ke kelas ini");
      }
      where.kelasId = kelasId;
    } else {
      where.kelasId = { in: kelasIds };
    }
  }

  const [total, data] = await Promise.all([
    prisma.siswa.count({ where }),
    prisma.siswa.findMany({ where, skip: (page - 1) * limit, take: limit, include: { kelas: true } }),
  ]);
  ok(res, data, undefined, { page, limit, total, totalPages: Math.ceil(total / limit) });
});

app.get("/api/siswa/search", authMiddleware, async (req: any, res) => {
  const q = String(req.query.q || "");
  const where: any = { deletedAt: null, OR: [{ nama: { contains: q } }, { nis: { contains: q } }] };
  ok(res, await prisma.siswa.findMany({ where, take: 20 }));
});

app.get("/api/siswa/:id", authMiddleware, async (req: any, res) => {
  const s = await prisma.siswa.findUnique({ where: { id: String(req.params.id) }, include: { kelas: true } });
  if (!s || s.deletedAt) return fail(res, 404, "NOT_FOUND", "Siswa tidak ditemukan");
  if (req.user.role === "GURU") {
    const g = await guruForUser(req.user.id);
    if (!g) return fail(res, 403, "FORBIDDEN", "Profil guru tidak ditemukan");
    const allowed = await isGuruOwnerOfSiswa(g.id, s.id);
    if (!allowed) return fail(res, 403, "FORBIDDEN", "Bukan tanggung jawab Anda");
  }
  ok(res, s);
});

app.post("/api/siswa", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const { nis, nama, jenisKelamin, tanggalLahir, alamat, namaOrangTua, noTelepon, kelasId } = req.body || {};
  try {
    const s = await prisma.siswa.create({
      data: {
        nis,
        nama,
        jenisKelamin: jenisKelamin || "LAKI_LAKI",
        tanggalLahir: new Date(tanggalLahir),
        alamat,
        namaOrangTua,
        noTelepon,
        kelasId: kelasId ? String(kelasId) : null,
      },
    });
    ok(res, s, "Created");
  } catch (err) {
    sendError(res, err);
  }
});

app.put("/api/siswa/:id", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const id = String(req.params.id);
  const { nis, nama, jenisKelamin, tanggalLahir, alamat, namaOrangTua, noTelepon, kelasId } = req.body || {};
  try {
    const s = await prisma.siswa.update({
      where: { id },
      data: {
        nis,
        nama,
        jenisKelamin,
        tanggalLahir: tanggalLahir ? new Date(tanggalLahir) : undefined,
        alamat,
        namaOrangTua,
        noTelepon,
        kelasId: kelasId !== undefined ? (kelasId ? String(kelasId) : null) : undefined,
      },
    });
    ok(res, s);
  } catch (err) {
    sendError(res, err);
  }
});

app.delete("/api/siswa/:id", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  try {
    await prisma.siswa.update({ where: { id: String(req.params.id) }, data: { deletedAt: new Date() } });
    ok(res, null);
  } catch (err) {
    sendError(res, err);
  }
});

app.get("/api/kelas/:id/siswa", authMiddleware, async (req, res) => {
  ok(res, await prisma.siswa.findMany({ where: { kelasId: String(req.params.id), deletedAt: null } }));
});

app.put("/api/kelas/:id/siswa", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const kelasId = String(req.params.id);
  const { siswaIds } = req.body || {};
  await prisma.siswa.updateMany({ where: { kelasId }, data: { kelasId: null } });
  if (Array.isArray(siswaIds)) {
    await prisma.siswa.updateMany({ where: { id: { in: siswaIds.map(String) } }, data: { kelasId } });
  }
  ok(res, null);
});

// ---------- PENUGASAN ----------
app.get("/api/penugasan", authMiddleware, async (_req, res) => {
  ok(res, await prisma.penugasanGuru.findMany({ include: { guru: true, kelas: true, mapel: true } }));
});

app.post("/api/penugasan", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const { guruId, kelasId, mataPelajaranId } = req.body || {};
  if (!guruId || !mataPelajaranId) return fail(res, 400, "VALIDATION_ERROR", "Guru dan mata pelajaran wajib dipilih");
  try {
    ok(res, await prisma.penugasanGuru.create({
      data: {
        guruId: String(guruId),
        kelasId: kelasId ? String(kelasId) : null,
        mataPelajaranId: String(mataPelajaranId),
      },
    }));
  } catch (err) {
    sendError(res, err);
  }
});

app.delete("/api/penugasan/:id", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  try {
    await prisma.penugasanGuru.delete({ where: { id: String(req.params.id) } });
    ok(res, null);
  } catch (err) {
    sendError(res, err);
  }
});

// ---------- NILAI ----------
app.get("/api/nilai", authMiddleware, async (req: any, res) => {
  const kelasId = req.query.kelasId ? String(req.query.kelasId) : undefined;
  const mapelId = req.query.mataPelajaranId ? String(req.query.mataPelajaranId) : undefined;
  const periode = req.query.periode ? String(req.query.periode) : undefined;
  const jenis = req.query.jenisNilai ? (String(req.query.jenisNilai) as any) : undefined;

  const where: any = {};
  if (kelasId) {
    const siswaIds = (await prisma.siswa.findMany({ where: { kelasId, deletedAt: null }, select: { id: true } })).map((s) => s.id);
    where.siswaId = { in: siswaIds };
  }
  if (mapelId) where.mataPelajaranId = mapelId;
  if (periode) where.periode = periode;
  if (jenis) where.jenis = jenis;

  ok(res, await prisma.nilai.findMany({ where, include: { siswa: true } }));
});

app.post("/api/nilai", authMiddleware, requireRole("GURU", "ADMIN"), async (req: any, res) => {
  const { siswaId, mataPelajaranId, periode, jenisNilai, nilai, pertemuan } = req.body || {};
  const n = Number(nilai);
  if (isNaN(n) || n < 0 || n > 100) return fail(res, 400, "VALIDATION_ERROR", "Nilai harus berupa angka di rentang 0-100");

  const siswa = await prisma.siswa.findUnique({ where: { id: String(siswaId) } });
  if (!siswa?.kelasId) return fail(res, 404, "NOT_FOUND", "Siswa tidak ditemukan atau belum memiliki kelas");

  let guruId: string;
  if (req.user.role === "GURU") {
    const g = await guruForUser(req.user.id);
    if (!g || !(await hasPenugasan(g.id, siswa.kelasId, String(mataPelajaranId)))) {
      return fail(res, 403, "FORBIDDEN", "Anda tidak memiliki penugasan untuk mengajar mapel ini di kelas siswa");
    }
    guruId = g.id;
  } else {
    guruId = String(req.body.guruId || req.user.id);
  }

  try {
    const v = await prisma.nilai.create({
      data: {
        siswaId: String(siswaId),
        mataPelajaranId: String(mataPelajaranId),
        guruId,
        periode,
        jenis: jenisNilai,
        pertemuan: pertemuan ? Number(pertemuan) : 1,
        nilai: n,
      },
    });
    ok(res, v, "Created");
  } catch (err) {
    sendError(res, err);
  }
});

app.post("/api/nilai/batch", authMiddleware, requireRole("GURU", "ADMIN"), async (req: any, res) => {
  const { items } = req.body || {};
  const created = [];
  const g = req.user.role === "GURU" ? await guruForUser(req.user.id) : null;
  if (req.user.role === "GURU" && !g) return fail(res, 403, "FORBIDDEN", "Profil guru tidak ditemukan");

  for (const it of items || []) {
    const siswa = await prisma.siswa.findUnique({ where: { id: String(it.siswaId) } });
    if (!siswa?.kelasId) continue;
    if (g && !(await hasPenugasan(g.id, siswa.kelasId, String(it.mataPelajaranId)))) continue;
    const guruId = g ? g.id : String(it.guruId || req.user.id);
    try {
      const v = await prisma.nilai.create({
        data: {
          siswaId: String(it.siswaId),
          mataPelajaranId: String(it.mataPelajaranId),
          guruId,
          periode: it.periode,
          jenis: it.jenisNilai,
          pertemuan: it.pertemuan ? Number(it.pertemuan) : 1,
          nilai: Number(it.nilai),
        },
      });
      created.push(v);
    } catch {}
  }
  ok(res, created);
});

app.put("/api/nilai/:id", authMiddleware, requireRole("GURU", "ADMIN"), async (req: any, res) => {
  const id = String(req.params.id);
  const { nilai } = req.body || {};
  const n = Number(nilai);
  if (isNaN(n) || n < 0 || n > 100) return fail(res, 400, "VALIDATION_ERROR", "Nilai harus di rentang 0-100");

  const existing = await prisma.nilai.findUnique({ where: { id } });
  if (!existing) return fail(res, 404, "NOT_FOUND", "Nilai tidak ditemukan");

  if (req.user.role === "GURU") {
    const g = await guruForUser(req.user.id);
    if (!g || g.id !== existing.guruId) return fail(res, 403, "FORBIDDEN", "Bukan pencatat nilai ini");
  }

  try {
    const v = await prisma.nilai.update({ where: { id }, data: { nilai: n } });
    await prisma.auditLog.create({
      data: {
        userId: req.user.id,
        aksi: "UPDATE",
        entitas: "nilai",
        entitasId: id,
        dataSebelum: { nilai: Number(existing.nilai) },
        dataSesudah: { nilai: n },
      },
    });
    ok(res, v);
  } catch (err) {
    sendError(res, err);
  }
});

app.get("/api/nilai/rata-rata", authMiddleware, async (req, res) => {
  const siswaId = String(req.query.siswaId);
  const periode = req.query.periode ? String(req.query.periode) : undefined;
  const where: any = { siswaId };
  if (periode) where.periode = periode;

  const vals = await prisma.nilai.findMany({ where });
  const byMapel: Record<string, number[]> = {};
  vals.forEach((v) => {
    byMapel[v.mataPelajaranId] = byMapel[v.mataPelajaranId] || [];
    byMapel[v.mataPelajaranId].push(Number(v.nilai));
  });

  const perMapel = Object.entries(byMapel).map(([m, arr]) => ({
    mataPelajaranId: m,
    rataRata: Math.round((arr.reduce((a, b) => a + b, 0) / arr.length) * 100) / 100,
  }));

  const all = vals.map((v) => Number(v.nilai));
  const keseluruhan = all.length ? Math.round((all.reduce((a, b) => a + b, 0) / all.length) * 100) / 100 : 0;
  ok(res, { perMapel, keseluruhan });
});

app.get("/api/nilai/perkembangan", authMiddleware, async (req, res) => {
  const siswaId = String(req.query.siswaId);
  const mapelId = String(req.query.mataPelajaranId);
  const vals = await prisma.nilai.findMany({ where: { siswaId, mataPelajaranId: mapelId }, orderBy: { createdAt: "asc" } });
  ok(res, vals);
});

// ---------- KEHADIRAN ----------
app.get("/api/kehadiran", authMiddleware, async (req, res) => {
  const kelasId = req.query.kelasId ? String(req.query.kelasId) : undefined;
  const mapelId = req.query.mataPelajaranId ? String(req.query.mataPelajaranId) : undefined;
  const tanggal = req.query.tanggal ? String(req.query.tanggal) : undefined;

  const where: any = {};
  if (kelasId) {
    const siswaIds = (await prisma.siswa.findMany({ where: { kelasId, deletedAt: null }, select: { id: true } })).map((s) => s.id);
    where.siswaId = { in: siswaIds };
  }
  if (mapelId) where.mataPelajaranId = mapelId;
  if (tanggal) where.tanggal = new Date(tanggal);

  ok(res, await prisma.kehadiran.findMany({ where, include: { siswa: true } }));
});

app.post("/api/kehadiran", authMiddleware, requireRole("GURU", "ADMIN"), async (req: any, res) => {
  const { siswaId, mataPelajaranId, tanggal, status, keterangan } = req.body || {};
  const siswa = await prisma.siswa.findUnique({ where: { id: String(siswaId) } });
  if (!siswa?.kelasId) return fail(res, 404, "NOT_FOUND", "Siswa tidak ditemukan");

  let guruId: string;
  if (req.user.role === "GURU") {
    const g = await guruForUser(req.user.id);
    if (!g || !(await hasPenugasan(g.id, siswa.kelasId, String(mataPelajaranId)))) {
      return fail(res, 403, "FORBIDDEN", "Tidak memiliki penugasan di kelas ini");
    }
    guruId = g.id;
  } else {
    guruId = String(req.body.guruId || req.user.id);
  }

  try {
    const v = await prisma.kehadiran.create({
      data: {
        siswaId: String(siswaId),
        mataPelajaranId: String(mataPelajaranId),
        guruId,
        tanggal: new Date(tanggal),
        status,
        keterangan,
      },
    });
    ok(res, v, "Created");
  } catch (err) {
    sendError(res, err);
  }
});

app.post("/api/kehadiran/batch", authMiddleware, requireRole("GURU", "ADMIN"), async (req: any, res) => {
  const { items } = req.body || {};
  const created = [];
  const g = req.user.role === "GURU" ? await guruForUser(req.user.id) : null;
  if (req.user.role === "GURU" && !g) return fail(res, 403, "FORBIDDEN", "Profil guru tidak ditemukan");

  for (const it of items || []) {
    const siswa = await prisma.siswa.findUnique({ where: { id: String(it.siswaId) } });
    if (!siswa?.kelasId) continue;
    const guruId = g ? g.id : String(it.guruId || req.user.id);
    try {
      const v = await prisma.kehadiran.create({
        data: {
          siswaId: String(it.siswaId),
          mataPelajaranId: String(it.mataPelajaranId),
          guruId,
          tanggal: new Date(it.tanggal),
          status: it.status,
          keterangan: it.keterangan,
        },
      });
      created.push(v);
    } catch {}
  }
  ok(res, created);
});

app.put("/api/kehadiran/:id", authMiddleware, requireRole("GURU", "ADMIN"), async (req, res) => {
  const { status, keterangan } = req.body || {};
  try {
    ok(res, await prisma.kehadiran.update({ where: { id: String(req.params.id) }, data: { status, keterangan } }));
  } catch (err) {
    sendError(res, err);
  }
});

app.get("/api/kehadiran/persentase", authMiddleware, async (req, res) => {
  const siswaId = String(req.query.siswaId);
  const mapelId = req.query.mataPelajaranId ? String(req.query.mataPelajaranId) : undefined;
  const where: any = { siswaId };
  if (mapelId) where.mataPelajaranId = mapelId;

  const all = await prisma.kehadiran.findMany({ where });
  const hadir = all.filter((k) => k.status === "HADIR").length;
  const pct = all.length ? (hadir / all.length) * 100 : 0;
  ok(res, { persentase: Math.round(pct * 100) / 100, total: all.length, hadir });
});

app.get("/api/kehadiran/riwayat", authMiddleware, async (req, res) => {
  ok(res, await prisma.kehadiran.findMany({ where: { siswaId: String(req.query.siswaId) }, orderBy: { tanggal: "desc" } }));
});

app.get("/api/kehadiran/peringatan", authMiddleware, async (_req, res) => {
  const threshold = env.ATTENDANCE_THRESHOLD;
  const siswaList = await prisma.siswa.findMany({ where: { deletedAt: null } });
  const result = [];
  for (const s of siswaList) {
    const all = await prisma.kehadiran.findMany({ where: { siswaId: s.id } });
    const hadir = all.filter((k) => k.status === "HADIR").length;
    const pct = all.length ? (hadir / all.length) * 100 : 100;
    if (pct < threshold) result.push({ siswa: s, persentase: Math.round(pct * 100) / 100 });
  }
  ok(res, result);
});

app.get("/api/pengaturan/ambang-kehadiran", authMiddleware, requireRole("ADMIN"), async (_req, res) => {
  const r = await prisma.pengaturanSistem.findUnique({ where: { kunci: "ATTENDANCE_THRESHOLD" } });
  ok(res, { value: r ? Number(r.nilai) : env.ATTENDANCE_THRESHOLD });
});

app.put("/api/pengaturan/ambang-kehadiran", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const { value } = req.body || {};
  await prisma.pengaturanSistem.upsert({
    where: { kunci: "ATTENDANCE_THRESHOLD" },
    create: { kunci: "ATTENDANCE_THRESHOLD", nilai: String(value) },
    update: { nilai: String(value) },
  });
  ok(res, { value });
});

// ---------- PRESTASI ----------
app.get("/api/prestasi/kategori", authMiddleware, (_req, res) => {
  ok(res, {
    bidang: ["SAINS", "OLAHRAGA", "SENI", "TEKNOLOGI", "BAHASA", "KEAGAMAAN"],
    tingkat: ["SEKOLAH", "KECAMATAN", "KABUPATEN", "PROVINSI", "NASIONAL", "INTERNASIONAL"],
  });
});

app.get("/api/prestasi", authMiddleware, async (req, res) => {
  const where: any = {};
  if (req.query.siswaId) where.siswaId = String(req.query.siswaId);
  if (req.query.bidang) where.bidang = String(req.query.bidang);
  if (req.query.tingkat) where.tingkat = req.query.tingkat as any;
  if (req.query.status) where.statusVerifikasi = req.query.status as any;
  const page = Number(req.query.page || 1);
  const limit = Number(req.query.limit || 20);

  const [total, data] = await Promise.all([
    prisma.prestasi.count({ where }),
    prisma.prestasi.findMany({ where, skip: (page - 1) * limit, take: limit, include: { bukti: true, siswa: true } }),
  ]);
  ok(res, data, undefined, { page, limit, total, totalPages: Math.ceil(total / limit) });
});

app.get("/api/prestasi/:id", authMiddleware, async (req, res) => {
  const p = await prisma.prestasi.findUnique({ where: { id: String(req.params.id) }, include: { bukti: true, siswa: true } });
  if (!p) return fail(res, 404, "NOT_FOUND", "Tidak ditemukan");
  ok(res, p);
});

app.post("/api/prestasi", authMiddleware, requireRole("GURU", "ADMIN"), async (req: any, res) => {
  const { siswaId, judul, bidang, tingkat, peringkat, tanggalPerolehan, penyelenggara } = req.body || {};
  let guruId: string;
  if (req.user.role === "GURU") {
    const g = await guruForUser(req.user.id);
    if (!g) return fail(res, 403, "FORBIDDEN", "Profil guru tidak ditemukan");
    guruId = g.id;
  } else {
    guruId = String(req.body.guruId || req.user.id);
  }
  try {
    const p = await prisma.prestasi.create({
      data: {
        siswaId: String(siswaId),
        judul,
        bidang,
        tingkat,
        peringkat,
        tanggalPerolehan: new Date(tanggalPerolehan),
        penyelenggara,
        dicatatOlehId: guruId,
        statusVerifikasi: "PENDING",
      },
    });
    ok(res, p, "Created");
  } catch (err) {
    sendError(res, err);
  }
});

app.put("/api/prestasi/:id", authMiddleware, requireRole("GURU", "ADMIN"), async (req: any, res) => {
  const id = String(req.params.id);
  const p = await prisma.prestasi.findUnique({ where: { id } });
  if (!p) return fail(res, 404, "NOT_FOUND", "Tidak ditemukan");
  if (p.statusVerifikasi === "DIVERIFIKASI" && req.user.role !== "ADMIN") {
    return fail(res, 422, "BUSINESS_RULE", "Prestasi yang telah diverifikasi hanya boleh diubah oleh Admin");
  }
  const { judul, bidang, tingkat, peringkat, tanggalPerolehan, penyelenggara } = req.body || {};
  try {
    ok(res, await prisma.prestasi.update({
      where: { id },
      data: {
        judul,
        bidang,
        tingkat,
        peringkat,
        tanggalPerolehan: tanggalPerolehan ? new Date(tanggalPerolehan) : undefined,
        penyelenggara,
      },
    }));
  } catch (err) {
    sendError(res, err);
  }
});

app.patch("/api/prestasi/:id/verifikasi", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const { status, catatanVerifikasi } = req.body || {};
  try {
    ok(res, await prisma.prestasi.update({
      where: { id: String(req.params.id) },
      data: {
        statusVerifikasi: status,
        catatanVerifikasi,
        diverifikasiOlehId: (req as any).user.id,
        diverifikasiAt: status === "DIVERIFIKASI" ? new Date() : null,
      },
    }));
  } catch (err) {
    sendError(res, err);
  }
});

app.delete("/api/prestasi/:id", authMiddleware, async (req: any, res) => {
  const p = await prisma.prestasi.findUnique({ where: { id: String(req.params.id) } });
  if (!p) return fail(res, 404, "NOT_FOUND", "Tidak ditemukan");
  if (req.user.role !== "ADMIN" && p.statusVerifikasi !== "PENDING") {
    return fail(res, 403, "FORBIDDEN", "Tidak dapat menghapus prestasi yang sudah diproses");
  }
  await prisma.prestasi.delete({ where: { id: String(req.params.id) } });
  ok(res, null);
});

const uploadDir = env.UPLOAD_DIR;
try {
  if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });
} catch (e) {
  console.warn("[WARN] Gagal membuat direktori upload:", e);
}

const storage = multer.diskStorage({
  destination: uploadDir,
  filename: (_req, file, cb) => cb(null, `${Date.now()}-${Math.random().toString(36).slice(2)}${path.extname(file.originalname)}`),
});

const upload = multer({
  storage,
  limits: { fileSize: env.MAX_UPLOAD_MB * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const allowed = ["application/pdf", "image/jpeg", "image/png"];
    if (!allowed.includes(file.mimetype)) return cb(new Error("Tipe file tidak diizinkan"));
    cb(null, true);
  },
});

app.post("/api/prestasi/:id/bukti", authMiddleware, upload.single("file"), async (req: any, res) => {
  const file = req.file;
  if (!file) return fail(res, 400, "VALIDATION_ERROR", "File wajib");
  try {
    const b = await prisma.buktiPrestasi.create({
      data: {
        prestasiId: String(req.params.id),
        namaFileAsli: file.originalname,
        namaFileSimpan: file.filename,
        mimeType: file.mimetype,
        ukuranByte: file.size,
        storagePath: file.path,
      },
    });
    ok(res, b, "Uploaded");
  } catch (err) {
    sendError(res, err);
  }
});

app.get("/api/prestasi/:id/bukti/:buktiId", authMiddleware, async (req, res) => {
  const b = await prisma.buktiPrestasi.findUnique({ where: { id: String(req.params.buktiId) } });
  if (!b) return fail(res, 404, "NOT_FOUND", "Tidak ditemukan");
  res.sendFile(path.resolve(b.storagePath));
});

app.delete("/api/prestasi/:id/bukti/:buktiId", authMiddleware, async (req, res) => {
  try {
    await prisma.buktiPrestasi.delete({ where: { id: String(req.params.buktiId) } });
    ok(res, null);
  } catch (err) {
    sendError(res, err);
  }
});

// ---------- CATATAN PERKEMBANGAN ----------
app.get("/api/catatan-perkembangan/kategori", authMiddleware, (_req, res) => {
  ok(res, { aspek: ["AKADEMIK", "SOSIAL", "EMOSIONAL", "KARAKTER", "KETERAMPILAN"] });
});

app.get("/api/catatan-perkembangan", authMiddleware, async (req, res) => {
  const where: any = {};
  if (req.query.siswaId) where.siswaId = String(req.query.siswaId);
  if (req.query.aspek) where.aspek = req.query.aspek as any;
  ok(res, await prisma.catatanPerkembangan.findMany({ where, orderBy: { tanggal: "desc" } }));
});

app.post("/api/catatan-perkembangan", authMiddleware, requireRole("GURU", "ADMIN"), async (req: any, res) => {
  const { siswaId, aspek, isi, tanggal } = req.body || {};
  let guruId: string;
  if (req.user.role === "GURU") {
    const g = await guruForUser(req.user.id);
    if (!g) return fail(res, 403, "FORBIDDEN", "Profil guru tidak ditemukan");
    guruId = g.id;
  } else {
    guruId = String(req.body.guruId || req.user.id);
  }
  try {
    ok(res, await prisma.catatanPerkembangan.create({
      data: {
        siswaId: String(siswaId),
        guruId,
        aspek,
        isi,
        tanggal: new Date(tanggal),
      },
    }), "Created");
  } catch (err) {
    sendError(res, err);
  }
});

app.put("/api/catatan-perkembangan/:id", authMiddleware, requireRole("GURU", "ADMIN"), async (req, res) => {
  const { aspek, isi, tanggal } = req.body || {};
  try {
    ok(res, await prisma.catatanPerkembangan.update({
      where: { id: String(req.params.id) },
      data: {
        aspek,
        isi,
        tanggal: tanggal ? new Date(tanggal) : undefined,
      },
    }));
  } catch (err) {
    sendError(res, err);
  }
});

app.delete("/api/catatan-perkembangan/:id", authMiddleware, requireRole("GURU", "ADMIN"), async (req, res) => {
  try {
    await prisma.catatanPerkembangan.delete({ where: { id: String(req.params.id) } });
    ok(res, null);
  } catch (err) {
    sendError(res, err);
  }
});

// ---------- MONITORING ----------
app.get("/api/monitoring/siswa/:id", authMiddleware, async (req, res) => {
  const id = String(req.params.id);
  const [nilai, kehadiran, prestasi] = await Promise.all([
    prisma.nilai.findMany({ where: { siswaId: id } }),
    prisma.kehadiran.findMany({ where: { siswaId: id } }),
    prisma.prestasi.findMany({ where: { siswaId: id } }),
  ]);
  ok(res, { nilai, kehadiran, prestasi });
});

app.get("/api/monitoring/indikator", authMiddleware, async (req, res) => {
  const kelasId = req.query.kelasId ? String(req.query.kelasId) : undefined;
  const periode = req.query.periode ? String(req.query.periode) : undefined;
  const siswaList = await prisma.siswa.findMany({ where: { deletedAt: null, ...(kelasId ? { kelasId } : {}) } });
  const result = [];
  for (const s of siswaList) {
    const nilai = await prisma.nilai.findMany({ where: { siswaId: s.id, ...(periode ? { periode } : {}) } });
    const avg = nilai.length ? nilai.reduce((a, b) => a + Number(b.nilai), 0) / nilai.length : 0;
    const kh = await prisma.kehadiran.findMany({ where: { siswaId: s.id } });
    const hadir = kh.length ? (kh.filter((k) => k.status === "HADIR").length / kh.length) * 100 : 100;
    let status = "BAIK";
    if (avg < 70 || hadir < env.ATTENDANCE_THRESHOLD) status = "PERHATIAN";
    if (avg < 60 || hadir < 60) status = "KRITIS";
    result.push({ siswaId: s.id, nama: s.nama, rataRata: Math.round(avg * 100) / 100, kehadiran: Math.round(hadir * 100) / 100, status });
  }
  ok(res, result);
});

app.get("/api/monitoring/penurunan", authMiddleware, async (req, res) => {
  const periode = String(req.query.periode || "");
  const siswaList = await prisma.siswa.findMany({ where: { deletedAt: null } });
  const result = [];
  for (const s of siswaList) {
    const cur = await prisma.nilai.findMany({ where: { siswaId: s.id, periode } });
    const avgCur = cur.length ? cur.reduce((a, b) => a + Number(b.nilai), 0) / cur.length : 0;
    const prev = await prisma.nilai.findMany({ where: { siswaId: s.id, NOT: { periode } } });
    const avgPrev = prev.length ? prev.reduce((a, b) => a + Number(b.nilai), 0) / prev.length : avgCur;
    if (avgPrev - avgCur > env.NILAI_DROP_THRESHOLD) {
      result.push({ siswaId: s.id, nama: s.nama, penurunan: Math.round((avgPrev - avgCur) * 100) / 100 });
    }
  }
  ok(res, result);
});

app.get("/api/monitoring/kehadiran-rendah", authMiddleware, async (_req, res) => {
  const siswaList = await prisma.siswa.findMany({ where: { deletedAt: null } });
  const result = [];
  for (const s of siswaList) {
    const all = await prisma.kehadiran.findMany({ where: { siswaId: s.id } });
    const hadir = all.filter((k) => k.status === "HADIR").length;
    const pct = all.length ? (hadir / all.length) * 100 : 100;
    if (pct < env.ATTENDANCE_THRESHOLD) result.push({ siswa: s, persentase: Math.round(pct * 100) / 100 });
  }
  ok(res, result);
});

app.get("/api/monitoring/tren", authMiddleware, async (req, res) => {
  const siswaId = String(req.query.siswaId);
  const nilai = await prisma.nilai.findMany({ where: { siswaId } });
  const keh = await prisma.kehadiran.findMany({ where: { siswaId } });
  ok(res, { nilai, kehadiran: keh });
});

// ---------- DASHBOARD ----------
app.get("/api/dashboard/admin", authMiddleware, requireRole("ADMIN"), async (_req, res) => {
  const [siswa, guru, kelas, prestasi, pending] = await Promise.all([
    prisma.siswa.count({ where: { deletedAt: null } }),
    prisma.guru.count({ where: { deletedAt: null } }),
    prisma.kelas.count({ where: { deletedAt: null } }),
    prisma.prestasi.count(),
    prisma.prestasi.count({ where: { statusVerifikasi: "PENDING" } }),
  ]);
  ok(res, { siswa, guru, kelas, prestasi, prestasiPending: pending });
});

app.get("/api/dashboard/guru", authMiddleware, requireRole("GURU"), async (req: any, res) => {
  const g = await guruForUser(req.user.id);
  if (!g) return ok(res, { kelasDiampu: 0, mapel: 0, siswa: 0 });
  const pens = await prisma.penugasanGuru.findMany({ where: { guruId: g.id } });
  const kelasIds = [...new Set(pens.map((p) => p.kelasId).filter((id): id is string => id !== null))];
  const siswaCount = await prisma.siswa.count({ where: { kelasId: { in: kelasIds }, deletedAt: null } });
  ok(res, { kelasDiampu: kelasIds.length, mapel: pens.length, siswa: siswaCount });
});

app.get("/api/dashboard/statistik", authMiddleware, async (req, res) => {
  const kelasId = req.query.kelasId ? String(req.query.kelasId) : undefined;
  const periode = req.query.periode ? String(req.query.periode) : undefined;
  const siswaList = await prisma.siswa.findMany({ where: { deletedAt: null, ...(kelasId ? { kelasId } : {}) } });
  const labels = siswaList.map((s) => s.nama);
  const nilai = [];
  for (const s of siswaList) {
    const vals = await prisma.nilai.findMany({ where: { siswaId: s.id, ...(periode ? { periode } : {}) } });
    nilai.push(vals.length ? vals.reduce((a, b) => a + Number(b.nilai), 0) / vals.length : 0);
  }
  ok(res, { labels, nilai });
});

// ---------- LAPORAN ----------
app.get("/api/laporan/siswa", authMiddleware, requireRole("ADMIN"), async (req, res) => {
  const format = String(req.query.format || "json");
  const data = await prisma.siswa.findMany({ where: { deletedAt: null }, include: { kelas: true } });
  if (format === "csv") {
    const csv = ["Nama,NIS,Kelas", ...data.map((s) => `${s.nama},${s.nis},${s.kelas?.nama || ""}`)].join("\n");
    res.setHeader("Content-Disposition", `attachment; filename="laporan-siswa-${Date.now()}.csv"`);
    res.type("text/csv").send(csv);
    return;
  }
  ok(res, data);
});

app.get("/api/laporan/nilai", authMiddleware, async (req, res) => {
  const format = String(req.query.format || "json");
  const data = await prisma.nilai.findMany({ include: { siswa: true, mapel: true } });
  if (format === "csv") {
    const csv = ["Siswa,Mapel,Nilai,Periode", ...data.map((n) => `${n.siswa.nama},${n.mapel.nama},${n.nilai},${n.periode}`)].join("\n");
    res.setHeader("Content-Disposition", `attachment; filename="laporan-nilai-${Date.now()}.csv"`);
    res.type("text/csv").send(csv);
    return;
  }
  ok(res, data);
});

app.get("/api/laporan/kehadiran", authMiddleware, async (req, res) => {
  const format = String(req.query.format || "json");
  const data = await prisma.kehadiran.findMany({ include: { siswa: true, mapel: true } });
  if (format === "csv") {
    const csv = ["Siswa,Mapel,Tanggal,Status", ...data.map((k) => `${k.siswa.nama},${k.mapel.nama},${k.tanggal.toISOString()},${k.status}`)].join("\n");
    res.setHeader("Content-Disposition", `attachment; filename="laporan-kehadiran-${Date.now()}.csv"`);
    res.type("text/csv").send(csv);
    return;
  }
  ok(res, data);
});

app.get("/api/laporan/prestasi", authMiddleware, async (req, res) => {
  const format = String(req.query.format || "json");
  const data = await prisma.prestasi.findMany({ include: { siswa: true } });
  if (format === "csv") {
    const csv = ["Siswa,Judul,Bidang,Tingkat,Status", ...data.map((p) => `${p.siswa.nama},${p.judul},${p.bidang},${p.tingkat},${p.statusVerifikasi}`)].join("\n");
    res.setHeader("Content-Disposition", `attachment; filename="laporan-prestasi-${Date.now()}.csv"`);
    res.type("text/csv").send(csv);
    return;
  }
  ok(res, data);
});

// ---------- error handler ----------
app.use((err: any, _req: any, res: any, _next: any) => {
  console.error("Unhandled Error:", err);
  sendError(res, err);
});

export default app;
