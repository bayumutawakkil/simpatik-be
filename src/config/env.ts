import dotenv from "dotenv";
dotenv.config();

const isProduction = process.env.NODE_ENV === "production";
const jwtSecret = process.env.JWT_SECRET || "";
if (isProduction && (jwtSecret.length < 32 || jwtSecret === "change-me-in-production")) {
  throw new Error("JWT_SECRET harus di-set dengan nilai kuat (minimal 32 karakter) di production");
}
if (isProduction && (!process.env.CORS_ORIGIN || process.env.CORS_ORIGIN === "*")) {
  throw new Error("CORS_ORIGIN wajib di-set dan tidak boleh * di production");
}

export const env = {
  DATABASE_URL: process.env.DATABASE_URL!,
  JWT_SECRET: jwtSecret,
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || "8h",
  PORT: Number(process.env.PORT || 4000),
  CORS_ORIGIN: process.env.CORS_ORIGIN || "http://localhost:8443",
  UPLOAD_DIR: process.env.UPLOAD_DIR || "./uploads",
  MAX_UPLOAD_MB: Number(process.env.MAX_UPLOAD_MB || 5),
  ATTENDANCE_THRESHOLD: Number(process.env.ATTENDANCE_THRESHOLD || 75),
  NILAI_DROP_THRESHOLD: Number(process.env.NILAI_DROP_THRESHOLD || 10),
  SEED_ADMIN_EMAIL: process.env.SEED_ADMIN_EMAIL || "admin@simpatik.local",
  SEED_ADMIN_PASSWORD: process.env.SEED_ADMIN_PASSWORD || "admin123",
};
