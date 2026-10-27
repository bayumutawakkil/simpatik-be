import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

/**
 * Instansiasi terpusat Prisma Client.
 * Mendukung logging query & error pada lingkungan development,
 * serta mencegah duplikasi instance pada mode hot-reload (ts-node-dev).
 */
export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === "development" ? ["query", "warn", "error"] : ["error"],
  });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}

// Graceful shutdown untuk menutup pool koneksi database
process.on("beforeExit", async () => {
  await prisma.$disconnect();
});
