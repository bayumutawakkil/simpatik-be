import path from "path";
import rateLimit from "express-rate-limit";

export const USER_PUBLIC_SELECT = {
  id: true,
  name: true,
  email: true,
  role: true,
  isActive: true,
} as const;

export function passwordPolicyError(password: unknown): string | null {
  if (typeof password !== "string" || password.length < 8 || !/[A-Za-z]/.test(password) || !/\d/.test(password)) {
    return "Password minimal 8 karakter, memuat huruf dan angka";
  }
  const weak = new Set(["password123", "admin123", "12345678", "password", "qwerty123"]);
  if (weak.has(password.toLowerCase())) {
    return "Password terlalu umum, pilih kombinasi yang lebih kuat";
  }
  return null;
}

export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number(process.env.LOGIN_RATE_LIMIT_MAX || 5),
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: { code: "RATE_LIMITED", message: "Terlalu banyak percobaan login. Coba lagi nanti." },
  },
});

export function resolveUploadPath(uploadDir: string, storedName: string): string | null {
  const safeName = path.basename(storedName || "");
  if (!safeName || safeName === "." || safeName === "..") return null;
  const root = path.resolve(uploadDir);
  const abs = path.resolve(root, safeName);
  const prefix = root.endsWith(path.sep) ? root : root + path.sep;
  if (abs !== root && !abs.startsWith(prefix)) return null;
  return abs;
}
