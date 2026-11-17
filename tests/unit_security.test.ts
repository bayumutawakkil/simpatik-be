import { resolve } from "path";
import { passwordPolicyError, resolveUploadPath, USER_PUBLIC_SELECT } from "../src/security";
import { handlePrismaError, AppError } from "../src/utils/prismaError";
import { Prisma } from "@prisma/client";

describe("Security & Validation Unit Tests", () => {
  describe("passwordPolicyError", () => {
    it("menolak password null / non-string", () => {
      expect(passwordPolicyError(null)).toContain("minimal 8 karakter");
      expect(passwordPolicyError(undefined)).toContain("minimal 8 karakter");
      expect(passwordPolicyError(12345678)).toContain("minimal 8 karakter");
    });

    it("menolak password kurang dari 8 karakter", () => {
      expect(passwordPolicyError("Abc1")).toContain("minimal 8 karakter");
    });

    it("menolak password hanya huruf tanpa angka", () => {
      expect(passwordPolicyError("PasswordLengkap")).toContain("memuat huruf dan angka");
    });

    it("menolak password hanya angka tanpa huruf", () => {
      expect(passwordPolicyError("1234567890")).toContain("memuat huruf dan angka");
    });

    it("menolak kata sandi yang terlalu umum/lemah", () => {
      expect(passwordPolicyError("admin123")).toContain("terlalu umum");
      expect(passwordPolicyError("password123")).toContain("terlalu umum");
      expect(passwordPolicyError("qwerty123")).toContain("terlalu umum");
    });

    it("menerima password yang valid dan kuat", () => {
      expect(passwordPolicyError("Rahasia1234#")).toBeNull();
      expect(passwordPolicyError("S1mpat1kSecure2026")).toBeNull();
    });
  });

  describe("resolveUploadPath", () => {
    const uploadBase = "d:/Project/simpatik/be/uploads";

    it("mengembalikan null untuk path kosong atau dot", () => {
      expect(resolveUploadPath(uploadBase, "")).toBeNull();
      expect(resolveUploadPath(uploadBase, ".")).toBeNull();
      expect(resolveUploadPath(uploadBase, "..")).toBeNull();
    });

    it("mencegah directory traversal attack", () => {
      const resolved = resolveUploadPath(uploadBase, "../../../windows/win.ini");
      expect(resolved).not.toBeNull();
      expect(resolved).toContain("win.ini");
    });

    it("mengembalikan path absolut yang valid untuk file normal", () => {
      const resolved = resolveUploadPath(uploadBase, "dokumen.pdf");
      expect(resolved).not.toBeNull();
      expect(resolved).toContain("dokumen.pdf");
    });
  });

  describe("USER_PUBLIC_SELECT", () => {
    it("tidak menyertakan field sensitif seperti passwordHash", () => {
      expect(USER_PUBLIC_SELECT).toHaveProperty("id", true);
      expect(USER_PUBLIC_SELECT).toHaveProperty("email", true);
      expect(USER_PUBLIC_SELECT).toHaveProperty("name", true);
      expect(USER_PUBLIC_SELECT).toHaveProperty("role", true);
      expect((USER_PUBLIC_SELECT as any).passwordHash).toBeUndefined();
    });
  });
});

describe("Prisma Error Handling Unit Tests", () => {
  it("mengembalikan instance AppError asli jika sudah AppError", () => {
    const customErr = new AppError(403, "FORBIDDEN", "Tidak berhak");
    const result = handlePrismaError(customErr);
    expect(result).toBe(customErr);
    expect(result.statusCode).toBe(403);
    expect(result.errorCode).toBe("FORBIDDEN");
  });

  it("menerjemahkan Prisma P2002 (Unique Constraint) menjadi 409 CONFLICT", () => {
    const p2002 = new Prisma.PrismaClientKnownRequestError("Unique constraint failed", {
      code: "P2002",
      clientVersion: "5.22.0",
      meta: { target: ["email"] }
    });
    const result = handlePrismaError(p2002);
    expect(result.statusCode).toBe(409);
    expect(result.errorCode).toBe("CONFLICT");
    expect(result.message).toContain("email");
  });

  it("menerjemahkan Prisma P2003 (Foreign Key Constraint) menjadi 400 FOREIGN_KEY_VIOLATION", () => {
    const p2003 = new Prisma.PrismaClientKnownRequestError("FK failed", {
      code: "P2003",
      clientVersion: "5.22.0",
      meta: { field_name: "kelasId" }
    });
    const result = handlePrismaError(p2003);
    expect(result.statusCode).toBe(400);
    expect(result.errorCode).toBe("FOREIGN_KEY_VIOLATION");
    expect(result.message).toContain("kelasId");
  });

  it("menerjemahkan Prisma P2025 (Record Not Found) menjadi 404 NOT_FOUND", () => {
    const p2025 = new Prisma.PrismaClientKnownRequestError("Record not found", {
      code: "P2025",
      clientVersion: "5.22.0",
      meta: { cause: "Siswa ID tidak ditemukan" }
    });
    const result = handlePrismaError(p2025);
    expect(result.statusCode).toBe(404);
    expect(result.errorCode).toBe("NOT_FOUND");
    expect(result.message).toBe("Siswa ID tidak ditemukan");
  });

  it("menerjemahkan PrismaClientValidationError menjadi 400 VALIDATION_ERROR", () => {
    const valErr = new Prisma.PrismaClientValidationError("Missing field", { clientVersion: "5.22.0" });
    const result = handlePrismaError(valErr);
    expect(result.statusCode).toBe(400);
    expect(result.errorCode).toBe("VALIDATION_ERROR");
  });

  it("menerjemahkan unknown error umum menjadi 500 INTERNAL_ERROR", () => {
    const generalErr = new Error("Database network drop");
    const result = handlePrismaError(generalErr);
    expect(result.statusCode).toBe(500);
    expect(result.errorCode).toBe("INTERNAL_ERROR");
  });
});
