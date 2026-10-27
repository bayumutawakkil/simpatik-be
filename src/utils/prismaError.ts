import { Prisma } from "@prisma/client";

export class AppError extends Error {
  public statusCode: number;
  public errorCode: string;
  public details?: any;

  constructor(statusCode: number, errorCode: string, message: string, details?: any) {
    super(message);
    this.name = "AppError";
    this.statusCode = statusCode;
    this.errorCode = errorCode;
    this.details = details;
  }
}

/**
 * Menerjemahkan kode error bawaan Prisma Client (P2002, P2003, P2025, dll)
 * menjadi AppError dengan HTTP status code dan format pesan yang ramah bagi client.
 */
export function handlePrismaError(err: unknown): AppError {
  if (err instanceof AppError) {
    return err;
  }

  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    switch (err.code) {
      case "P2002": {
        // Unique constraint failed
        const target = (err.meta?.target as string[]) || [];
        const fieldName = Array.isArray(target) ? target.join(", ") : String(target || "field");
        return new AppError(
          409,
          "CONFLICT",
          `Data duplikat: nilai unik untuk ${fieldName} sudah terdaftar dalam sistem.`,
          { target: err.meta?.target }
        );
      }
      case "P2003": {
        // Foreign key constraint failed
        const fieldName = (err.meta?.field_name as string) || "relasi terkait";
        return new AppError(
          400,
          "FOREIGN_KEY_VIOLATION",
          `Operasi ditolak: data referensi pada ${fieldName} tidak ditemukan atau masih berelasi dengan data lain.`,
          { fieldName: err.meta?.field_name }
        );
      }
      case "P2025": {
        // Record to update/delete not found
        return new AppError(
          404,
          "NOT_FOUND",
          (err.meta?.cause as string) || "Data yang diminta tidak ditemukan dalam basis data."
        );
      }
      default:
        return new AppError(
          500,
          `PRISMA_${err.code}`,
          `Terjadi kesalahan pada query basis data: ${err.message}`
        );
    }
  }

  if (err instanceof Prisma.PrismaClientValidationError) {
    return new AppError(400, "VALIDATION_ERROR", "Format data atau parameter query tidak valid.");
  }

  if (err instanceof Error) {
    return new AppError(500, "INTERNAL_ERROR", err.message);
  }

  return new AppError(500, "INTERNAL_ERROR", "Terjadi kesalahan server internal.");
}
