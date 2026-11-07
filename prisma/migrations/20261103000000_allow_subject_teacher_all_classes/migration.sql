-- Guru mapel dapat ditugaskan ke semua kelas ketika kelas_id bernilai NULL.
ALTER TABLE "penugasan_guru"
  ALTER COLUMN "kelas_id" DROP NOT NULL;
