-- ============================================================================
-- PRISMA INITIAL MIGRATION: 20261020000000_init
-- SISTEM MANAJEMEN DATA AKADEMIK SISWA (SIMPATIK)
-- ============================================================================

-- ============================================================================
-- BAGIAN 1: EKSTENSI & ENUMS
-- ============================================================================

-- Ekstensi PostgreSQL
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Tipe ENUM
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'role_pengguna') THEN
    CREATE TYPE "role_pengguna" AS ENUM ('ADMIN', 'GURU');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'jenis_kelamin') THEN
    CREATE TYPE "jenis_kelamin" AS ENUM ('LAKI_LAKI', 'PEREMPUAN');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'jenis_nilai') THEN
    CREATE TYPE "jenis_nilai" AS ENUM ('HARIAN', 'TUGAS', 'UTS', 'UAS');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_kehadiran') THEN
    CREATE TYPE "status_kehadiran" AS ENUM ('HADIR', 'SAKIT', 'IZIN', 'ALPA');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tingkat_prestasi') THEN
    CREATE TYPE "tingkat_prestasi" AS ENUM ('SEKOLAH', 'KECAMATAN', 'KABUPATEN', 'PROVINSI', 'NASIONAL', 'INTERNASIONAL');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_verifikasi') THEN
    CREATE TYPE "status_verifikasi" AS ENUM ('PENDING', 'DIVERIFIKASI', 'DITOLAK');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'aspek_perkembangan') THEN
    CREATE TYPE "aspek_perkembangan" AS ENUM ('AKADEMIK', 'SOSIAL', 'EMOSIONAL', 'KARAKTER', 'KETERAMPILAN');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_perkembangan_siswa') THEN
    CREATE TYPE "status_perkembangan_siswa" AS ENUM ('BAIK', 'PERHATIAN', 'KRITIS');
  END IF;
END
$$;

-- ============================================================================
-- BAGIAN 2: TABEL INTI PRISMA SCHEMA
-- ============================================================================

-- CreateTable users
CREATE TABLE IF NOT EXISTS "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(100) NOT NULL,
    "email" CITEXT NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "role" "role_pengguna" NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "last_login_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable guru
CREATE TABLE IF NOT EXISTS "guru" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID,
    "nip" VARCHAR(30) NOT NULL,
    "nama" VARCHAR(100) NOT NULL,
    "alamat" TEXT,
    "no_telepon" VARCHAR(20),
    "deleted_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "guru_pkey" PRIMARY KEY ("id")
);

-- CreateTable kelas
CREATE TABLE IF NOT EXISTS "kelas" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "nama" VARCHAR(50) NOT NULL,
    "tingkat" SMALLINT NOT NULL,
    "tahun_ajaran" VARCHAR(9) NOT NULL,
    "wali_kelas_id" UUID,
    "deleted_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "kelas_pkey" PRIMARY KEY ("id")
);

-- CreateTable siswa
CREATE TABLE IF NOT EXISTS "siswa" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "nis" VARCHAR(20) NOT NULL,
    "nama" VARCHAR(100) NOT NULL,
    "jenis_kelamin" "jenis_kelamin" NOT NULL,
    "tanggal_lahir" DATE NOT NULL,
    "alamat" TEXT,
    "nama_orang_tua" VARCHAR(100),
    "no_telepon" VARCHAR(20),
    "kelas_id" UUID,
    "deleted_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "siswa_pkey" PRIMARY KEY ("id")
);

-- CreateTable mata_pelajaran
CREATE TABLE IF NOT EXISTS "mata_pelajaran" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "kode" VARCHAR(10) NOT NULL,
    "nama" VARCHAR(100) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "mata_pelajaran_pkey" PRIMARY KEY ("id")
);

-- CreateTable penugasan_guru
CREATE TABLE IF NOT EXISTS "penugasan_guru" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "guru_id" UUID NOT NULL,
    "kelas_id" UUID NOT NULL,
    "mata_pelajaran_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "penugasan_guru_pkey" PRIMARY KEY ("id")
);

-- CreateTable nilai
CREATE TABLE IF NOT EXISTS "nilai" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "siswa_id" UUID NOT NULL,
    "mata_pelajaran_id" UUID NOT NULL,
    "guru_id" UUID NOT NULL,
    "periode" VARCHAR(20) NOT NULL,
    "jenis" "jenis_nilai" NOT NULL,
    "pertemuan" SMALLINT NOT NULL DEFAULT 1,
    "nilai" DECIMAL(5,2) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "nilai_pkey" PRIMARY KEY ("id")
);

-- CreateTable kehadiran
CREATE TABLE IF NOT EXISTS "kehadiran" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "siswa_id" UUID NOT NULL,
    "mata_pelajaran_id" UUID NOT NULL,
    "guru_id" UUID NOT NULL,
    "tanggal" DATE NOT NULL,
    "status" "status_kehadiran" NOT NULL,
    "keterangan" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "kehadiran_pkey" PRIMARY KEY ("id")
);

-- CreateTable prestasi
CREATE TABLE IF NOT EXISTS "prestasi" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "siswa_id" UUID NOT NULL,
    "judul" VARCHAR(200) NOT NULL,
    "bidang" VARCHAR(50) NOT NULL,
    "tingkat" "tingkat_prestasi" NOT NULL,
    "peringkat" VARCHAR(50),
    "tanggal_perolehan" DATE NOT NULL,
    "penyelenggara" VARCHAR(150),
    "status_verifikasi" "status_verifikasi" NOT NULL DEFAULT 'PENDING',
    "catatan_verifikasi" TEXT,
    "dicatat_oleh_id" UUID NOT NULL,
    "diverifikasi_oleh_id" UUID,
    "diverifikasi_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "prestasi_pkey" PRIMARY KEY ("id")
);

-- CreateTable bukti_prestasi
CREATE TABLE IF NOT EXISTS "bukti_prestasi" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "prestasi_id" UUID NOT NULL,
    "nama_file_asli" VARCHAR(255) NOT NULL,
    "nama_file_simpan" VARCHAR(255) NOT NULL,
    "mime_type" VARCHAR(100) NOT NULL,
    "ukuran_byte" INTEGER NOT NULL,
    "storage_path" TEXT NOT NULL,
    "uploaded_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "bukti_prestasi_pkey" PRIMARY KEY ("id")
);

-- CreateTable catatan_perkembangan
CREATE TABLE IF NOT EXISTS "catatan_perkembangan" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "siswa_id" UUID NOT NULL,
    "guru_id" UUID NOT NULL,
    "aspek" "aspek_perkembangan" NOT NULL,
    "isi" TEXT NOT NULL,
    "tanggal" DATE NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "catatan_perkembangan_pkey" PRIMARY KEY ("id")
);

-- CreateTable pengaturan_sistem
CREATE TABLE IF NOT EXISTS "pengaturan_sistem" (
    "kunci" VARCHAR(50) NOT NULL,
    "nilai" VARCHAR(255) NOT NULL,
    "keterangan" TEXT,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pengaturan_sistem_pkey" PRIMARY KEY ("kunci")
);

-- CreateTable audit_log
CREATE TABLE IF NOT EXISTS "audit_log" (
    "id" BIGSERIAL NOT NULL,
    "user_id" UUID,
    "aksi" VARCHAR(20) NOT NULL,
    "entitas" VARCHAR(50) NOT NULL,
    "entitas_id" UUID,
    "data_sebelum" JSONB,
    "data_sesudah" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_log_pkey" PRIMARY KEY ("id")
);

-- ============================================================================
-- BAGIAN 3: INDEX & UNIQUE CONSTRAINT BAWAAN PRISMA
-- ============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS "users_email_key" ON "users"("email");
CREATE UNIQUE INDEX IF NOT EXISTS "guru_user_id_key" ON "guru"("user_id");
CREATE UNIQUE INDEX IF NOT EXISTS "guru_nip_key" ON "guru"("nip");
CREATE UNIQUE INDEX IF NOT EXISTS "uq_kelas_nama_tahun_ajaran" ON "kelas"("nama", "tahun_ajaran");
CREATE UNIQUE INDEX IF NOT EXISTS "siswa_nis_key" ON "siswa"("nis");
CREATE UNIQUE INDEX IF NOT EXISTS "mata_pelajaran_kode_key" ON "mata_pelajaran"("kode");
CREATE UNIQUE INDEX IF NOT EXISTS "uq_penugasan_guru_kelas_mapel" ON "penugasan_guru"("guru_id", "kelas_id", "mata_pelajaran_id");
CREATE INDEX IF NOT EXISTS "idx_penugasan_guru_guru_id" ON "penugasan_guru"("guru_id");
CREATE INDEX IF NOT EXISTS "idx_penugasan_guru_kelas_id" ON "penugasan_guru"("kelas_id");
CREATE UNIQUE INDEX IF NOT EXISTS "uq_nilai_siswa_mapel_periode_jenis_pertemuan" ON "nilai"("siswa_id", "mata_pelajaran_id", "periode", "jenis", "pertemuan");
CREATE INDEX IF NOT EXISTS "idx_nilai_siswa_mapel_periode" ON "nilai"("siswa_id", "mata_pelajaran_id", "periode");
CREATE INDEX IF NOT EXISTS "idx_nilai_mapel_periode" ON "nilai"("mata_pelajaran_id", "periode");
CREATE UNIQUE INDEX IF NOT EXISTS "uq_kehadiran_siswa_mapel_tanggal" ON "kehadiran"("siswa_id", "mata_pelajaran_id", "tanggal");
CREATE INDEX IF NOT EXISTS "idx_kehadiran_siswa_tanggal" ON "kehadiran"("siswa_id", "tanggal");
CREATE INDEX IF NOT EXISTS "idx_kehadiran_mapel_tanggal" ON "kehadiran"("mata_pelajaran_id", "tanggal");
CREATE INDEX IF NOT EXISTS "idx_prestasi_siswa_id" ON "prestasi"("siswa_id");
CREATE INDEX IF NOT EXISTS "idx_prestasi_status_verifikasi" ON "prestasi"("status_verifikasi");
CREATE INDEX IF NOT EXISTS "idx_prestasi_bidang_tingkat" ON "prestasi"("bidang", "tingkat");
CREATE UNIQUE INDEX IF NOT EXISTS "bukti_prestasi_nama_file_simpan_key" ON "bukti_prestasi"("nama_file_simpan");
CREATE INDEX IF NOT EXISTS "idx_catatan_perkembangan_siswa_tanggal" ON "catatan_perkembangan"("siswa_id", "tanggal" DESC);
CREATE INDEX IF NOT EXISTS "idx_audit_log_entitas_entitas_id" ON "audit_log"("entitas", "entitas_id");
CREATE INDEX IF NOT EXISTS "idx_audit_log_created_at_desc" ON "audit_log"("created_at" DESC);

-- ============================================================================
-- BAGIAN 4: FOREIGN KEYS
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'guru_user_id_fkey') THEN
    ALTER TABLE "guru" ADD CONSTRAINT "guru_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'kelas_wali_kelas_id_fkey') THEN
    ALTER TABLE "kelas" ADD CONSTRAINT "kelas_wali_kelas_id_fkey" FOREIGN KEY ("wali_kelas_id") REFERENCES "guru"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'siswa_kelas_id_fkey') THEN
    ALTER TABLE "siswa" ADD CONSTRAINT "siswa_kelas_id_fkey" FOREIGN KEY ("kelas_id") REFERENCES "kelas"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'penugasan_guru_guru_id_fkey') THEN
    ALTER TABLE "penugasan_guru" ADD CONSTRAINT "penugasan_guru_guru_id_fkey" FOREIGN KEY ("guru_id") REFERENCES "guru"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'penugasan_guru_kelas_id_fkey') THEN
    ALTER TABLE "penugasan_guru" ADD CONSTRAINT "penugasan_guru_kelas_id_fkey" FOREIGN KEY ("kelas_id") REFERENCES "kelas"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'penugasan_guru_mata_pelajaran_id_fkey') THEN
    ALTER TABLE "penugasan_guru" ADD CONSTRAINT "penugasan_guru_mata_pelajaran_id_fkey" FOREIGN KEY ("mata_pelajaran_id") REFERENCES "mata_pelajaran"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'nilai_siswa_id_fkey') THEN
    ALTER TABLE "nilai" ADD CONSTRAINT "nilai_siswa_id_fkey" FOREIGN KEY ("siswa_id") REFERENCES "siswa"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'nilai_mata_pelajaran_id_fkey') THEN
    ALTER TABLE "nilai" ADD CONSTRAINT "nilai_mata_pelajaran_id_fkey" FOREIGN KEY ("mata_pelajaran_id") REFERENCES "mata_pelajaran"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'nilai_guru_id_fkey') THEN
    ALTER TABLE "nilai" ADD CONSTRAINT "nilai_guru_id_fkey" FOREIGN KEY ("guru_id") REFERENCES "guru"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'kehadiran_siswa_id_fkey') THEN
    ALTER TABLE "kehadiran" ADD CONSTRAINT "kehadiran_siswa_id_fkey" FOREIGN KEY ("siswa_id") REFERENCES "siswa"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'kehadiran_mata_pelajaran_id_fkey') THEN
    ALTER TABLE "kehadiran" ADD CONSTRAINT "kehadiran_mata_pelajaran_id_fkey" FOREIGN KEY ("mata_pelajaran_id") REFERENCES "mata_pelajaran"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'kehadiran_guru_id_fkey') THEN
    ALTER TABLE "kehadiran" ADD CONSTRAINT "kehadiran_guru_id_fkey" FOREIGN KEY ("guru_id") REFERENCES "guru"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prestasi_siswa_id_fkey') THEN
    ALTER TABLE "prestasi" ADD CONSTRAINT "prestasi_siswa_id_fkey" FOREIGN KEY ("siswa_id") REFERENCES "siswa"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prestasi_dicatat_oleh_id_fkey') THEN
    ALTER TABLE "prestasi" ADD CONSTRAINT "prestasi_dicatat_oleh_id_fkey" FOREIGN KEY ("dicatat_oleh_id") REFERENCES "guru"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'prestasi_diverifikasi_oleh_id_fkey') THEN
    ALTER TABLE "prestasi" ADD CONSTRAINT "prestasi_diverifikasi_oleh_id_fkey" FOREIGN KEY ("diverifikasi_oleh_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'bukti_prestasi_prestasi_id_fkey') THEN
    ALTER TABLE "bukti_prestasi" ADD CONSTRAINT "bukti_prestasi_prestasi_id_fkey" FOREIGN KEY ("prestasi_id") REFERENCES "prestasi"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'catatan_perkembangan_siswa_id_fkey') THEN
    ALTER TABLE "catatan_perkembangan" ADD CONSTRAINT "catatan_perkembangan_siswa_id_fkey" FOREIGN KEY ("siswa_id") REFERENCES "siswa"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'catatan_perkembangan_guru_id_fkey') THEN
    ALTER TABLE "catatan_perkembangan" ADD CONSTRAINT "catatan_perkembangan_guru_id_fkey" FOREIGN KEY ("guru_id") REFERENCES "guru"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'audit_log_user_id_fkey') THEN
    ALTER TABLE "audit_log" ADD CONSTRAINT "audit_log_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END
$$;

-- ============================================================================
-- BAGIAN 5: SQL MANUAL TAMBAHAN (FITUR DI LUAR DUKUNGAN NATIVE PRISMA)
-- ============================================================================

-- 5.1 CHECK Constraints
DO $$
BEGIN
  -- Check nilai antara 0 s.d 100
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_nilai_rentang') THEN
    ALTER TABLE "nilai" ADD CONSTRAINT "chk_nilai_rentang" CHECK ("nilai" >= 0 AND "nilai" <= 100);
  END IF;

  -- Check tingkat kelas 1 s.d 12
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_kelas_tingkat') THEN
    ALTER TABLE "kelas" ADD CONSTRAINT "chk_kelas_tingkat" CHECK ("tingkat" >= 1 AND "tingkat" <= 12);
  END IF;

  -- Check format tahun ajaran YYYY/YYYY
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_kelas_tahun_ajaran') THEN
    ALTER TABLE "kelas" ADD CONSTRAINT "chk_kelas_tahun_ajaran" CHECK ("tahun_ajaran" ~ '^\d{4}/\d{4}$');
  END IF;

  -- Check tanggal lahir tidak di masa depan
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_siswa_tanggal_lahir') THEN
    ALTER TABLE "siswa" ADD CONSTRAINT "chk_siswa_tanggal_lahir" CHECK ("tanggal_lahir" <= CURRENT_DATE);
  END IF;

  -- Check bukti prestasi (mime type dan max size 5 MB)
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_bukti_prestasi_mime') THEN
    ALTER TABLE "bukti_prestasi" ADD CONSTRAINT "chk_bukti_prestasi_mime" CHECK ("mime_type" IN ('application/pdf', 'image/jpeg', 'image/png'));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_bukti_prestasi_ukuran') THEN
    ALTER TABLE "bukti_prestasi" ADD CONSTRAINT "chk_bukti_prestasi_ukuran" CHECK ("ukuran_byte" > 0 AND "ukuran_byte" <= 5242880);
  END IF;

  -- Check verifikasi prestasi: jika DIVERIFIKASI maka verifikator dan waktu wajib terisi
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_prestasi_verifikasi') THEN
    ALTER TABLE "prestasi" ADD CONSTRAINT "chk_prestasi_verifikasi" CHECK (
      ("status_verifikasi" = 'DIVERIFIKASI' AND "diverifikasi_oleh_id" IS NOT NULL AND "diverifikasi_at" IS NOT NULL)
      OR
      ("status_verifikasi" <> 'DIVERIFIKASI')
    );
  END IF;
END
$$;

-- 5.2 Partial Index & GIN Trigram
CREATE INDEX IF NOT EXISTS "idx_siswa_kelas_id_active"
  ON "siswa" ("kelas_id")
  WHERE "deleted_at" IS NULL;

CREATE INDEX IF NOT EXISTS "idx_siswa_nama_trgm"
  ON "siswa" USING gin ("nama" gin_trgm_ops);

CREATE INDEX IF NOT EXISTS "idx_siswa_lower_nama"
  ON "siswa" (lower("nama"));

CREATE INDEX IF NOT EXISTS "idx_guru_nama_trgm"
  ON "guru" USING gin ("nama" gin_trgm_ops);

-- 5.3 Fungsi dan Triggers
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_guru_updated_at ON guru;
CREATE TRIGGER trg_guru_updated_at BEFORE UPDATE ON guru FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_kelas_updated_at ON kelas;
CREATE TRIGGER trg_kelas_updated_at BEFORE UPDATE ON kelas FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_siswa_updated_at ON siswa;
CREATE TRIGGER trg_siswa_updated_at BEFORE UPDATE ON siswa FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_mata_pelajaran_updated_at ON mata_pelajaran;
CREATE TRIGGER trg_mata_pelajaran_updated_at BEFORE UPDATE ON mata_pelajaran FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_nilai_updated_at ON nilai;
CREATE TRIGGER trg_nilai_updated_at BEFORE UPDATE ON nilai FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_kehadiran_updated_at ON kehadiran;
CREATE TRIGGER trg_kehadiran_updated_at BEFORE UPDATE ON kehadiran FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_prestasi_updated_at ON prestasi;
CREATE TRIGGER trg_prestasi_updated_at BEFORE UPDATE ON prestasi FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_catatan_perkembangan_updated_at ON catatan_perkembangan;
CREATE TRIGGER trg_catatan_perkembangan_updated_at BEFORE UPDATE ON catatan_perkembangan FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_pengaturan_sistem_updated_at ON pengaturan_sistem;
CREATE TRIGGER trg_pengaturan_sistem_updated_at BEFORE UPDATE ON pengaturan_sistem FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Trigger Sinkronisasi Tanggal Verifikasi Prestasi
CREATE OR REPLACE FUNCTION trg_fn_prestasi_status_verifikasi()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status_verifikasi = 'DIVERIFIKASI' AND (OLD IS NULL OR OLD.status_verifikasi <> 'DIVERIFIKASI') THEN
    IF NEW.diverifikasi_at IS NULL THEN
      NEW.diverifikasi_at := now();
    END IF;
  ELSIF NEW.status_verifikasi <> 'DIVERIFIKASI' THEN
    NEW.diverifikasi_at := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prestasi_verifikasi_sync ON prestasi;
CREATE TRIGGER trg_prestasi_verifikasi_sync
  BEFORE INSERT OR UPDATE OF status_verifikasi ON prestasi
  FOR EACH ROW
  EXECUTE FUNCTION trg_fn_prestasi_status_verifikasi();

-- Trigger Audit Log
CREATE OR REPLACE FUNCTION catat_audit()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID := NULL;
  v_session_user_str TEXT;
  v_entitas_id UUID := NULL;
  v_data_sebelum JSONB := NULL;
  v_data_sesudah JSONB := NULL;
BEGIN
  BEGIN
    v_session_user_str := current_setting('simpatik.current_user_id', true);
    IF v_session_user_str IS NOT NULL AND v_session_user_str ~ '^[0-9a-fA-F-]{36}$' THEN
      v_user_id := v_session_user_str::UUID;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_user_id := NULL;
  END;

  IF TG_OP = 'INSERT' THEN
    v_entitas_id := NEW.id;
    v_data_sesudah := to_jsonb(NEW);
    INSERT INTO audit_log (user_id, aksi, entitas, entitas_id, data_sebelum, data_sesudah, created_at)
    VALUES (v_user_id, 'CREATE', TG_TABLE_NAME, v_entitas_id, NULL, v_data_sesudah, now());
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    v_entitas_id := NEW.id;
    v_data_sebelum := to_jsonb(OLD);
    v_data_sesudah := to_jsonb(NEW);
    INSERT INTO audit_log (user_id, aksi, entitas, entitas_id, data_sebelum, data_sesudah, created_at)
    VALUES (v_user_id, 'UPDATE', TG_TABLE_NAME, v_entitas_id, v_data_sebelum, v_data_sesudah, now());
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    v_entitas_id := OLD.id;
    v_data_sebelum := to_jsonb(OLD);
    INSERT INTO audit_log (user_id, aksi, entitas, entitas_id, data_sebelum, data_sesudah, created_at)
    VALUES (v_user_id, 'DELETE', TG_TABLE_NAME, v_entitas_id, v_data_sebelum, NULL, now());
    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_users ON users;
CREATE TRIGGER trg_audit_users AFTER INSERT OR UPDATE OR DELETE ON users FOR EACH ROW EXECUTE FUNCTION catat_audit();

DROP TRIGGER IF EXISTS trg_audit_nilai ON nilai;
CREATE TRIGGER trg_audit_nilai AFTER INSERT OR UPDATE OR DELETE ON nilai FOR EACH ROW EXECUTE FUNCTION catat_audit();

DROP TRIGGER IF EXISTS trg_audit_kehadiran ON kehadiran;
CREATE TRIGGER trg_audit_kehadiran AFTER INSERT OR UPDATE OR DELETE ON kehadiran FOR EACH ROW EXECUTE FUNCTION catat_audit();

DROP TRIGGER IF EXISTS trg_audit_prestasi ON prestasi;
CREATE TRIGGER trg_audit_prestasi AFTER INSERT OR UPDATE OR DELETE ON prestasi FOR EACH ROW EXECUTE FUNCTION catat_audit();

-- Trigger Validasi Kepemilikan Penugasan Guru
CREATE OR REPLACE FUNCTION validasi_penugasan_guru()
RETURNS TRIGGER AS $$
DECLARE
  v_siswa_kelas_id UUID;
  v_ada_penugasan BOOLEAN;
BEGIN
  SELECT kelas_id INTO v_siswa_kelas_id FROM siswa WHERE id = NEW.siswa_id;

  IF v_siswa_kelas_id IS NULL THEN
    RAISE EXCEPTION 'Siswa % belum dimasukkan ke dalam kelas.', NEW.siswa_id;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM penugasan_guru
    WHERE guru_id = NEW.guru_id
      AND kelas_id = v_siswa_kelas_id
      AND mata_pelajaran_id = NEW.mata_pelajaran_id
  ) INTO v_ada_penugasan;

  IF NOT v_ada_penugasan THEN
    RAISE EXCEPTION 'Pelanggaran Penugasan: Guru % tidak ditugaskan untuk mengajar mapel % di kelas siswa %',
      NEW.guru_id, NEW.mata_pelajaran_id, v_siswa_kelas_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validasi_nilai_penugasan ON nilai;
CREATE TRIGGER trg_validasi_nilai_penugasan
  BEFORE INSERT OR UPDATE OF siswa_id, mata_pelajaran_id, guru_id ON nilai
  FOR EACH ROW EXECUTE FUNCTION validasi_penugasan_guru();

DROP TRIGGER IF EXISTS trg_validasi_kehadiran_penugasan ON kehadiran;
CREATE TRIGGER trg_validasi_kehadiran_penugasan
  BEFORE INSERT OR UPDATE OF siswa_id, mata_pelajaran_id, guru_id ON kehadiran
  FOR EACH ROW EXECUTE FUNCTION validasi_penugasan_guru();

-- 5.4 Views Dashboard & Analytical
CREATE OR REPLACE VIEW v_siswa_aktif AS
SELECT
  s.id AS siswa_id,
  s.nis,
  s.nama AS nama_siswa,
  s.jenis_kelamin,
  s.tanggal_lahir,
  s.alamat,
  s.nama_orang_tua,
  s.no_telepon,
  k.id AS kelas_id,
  k.nama AS nama_kelas,
  k.tingkat AS tingkat_kelas,
  k.tahun_ajaran,
  g.id AS wali_kelas_id,
  g.nama AS nama_wali_kelas,
  g.nip AS nip_wali_kelas
FROM siswa s
LEFT JOIN kelas k ON s.kelas_id = k.id AND k.deleted_at IS NULL
LEFT JOIN guru g ON k.wali_kelas_id = g.id AND g.deleted_at IS NULL
WHERE s.deleted_at IS NULL;

CREATE OR REPLACE VIEW v_rata_rata_nilai_siswa AS
SELECT
  n.siswa_id,
  s.nis,
  s.nama AS nama_siswa,
  n.mata_pelajaran_id,
  mp.kode AS kode_mapel,
  mp.nama AS nama_mapel,
  n.periode,
  ROUND(AVG(n.nilai), 2) AS rata_rata,
  COUNT(n.id) AS jumlah_komponen_nilai,
  MIN(n.nilai) AS nilai_terendah,
  MAX(n.nilai) AS nilai_tertinggi
FROM nilai n
JOIN siswa s ON n.siswa_id = s.id AND s.deleted_at IS NULL
JOIN mata_pelajaran mp ON n.mata_pelajaran_id = mp.id AND mp.deleted_at IS NULL
GROUP BY
  n.siswa_id, s.nis, s.nama, n.mata_pelajaran_id, mp.kode, mp.nama, n.periode;

CREATE OR REPLACE VIEW v_persentase_kehadiran AS
SELECT
  kh.siswa_id,
  s.nis,
  s.nama AS nama_siswa,
  s.kelas_id,
  k.nama AS nama_kelas,
  kh.mata_pelajaran_id,
  mp.kode AS kode_mapel,
  mp.nama AS nama_mapel,
  COUNT(kh.id) AS total_pertemuan,
  COUNT(kh.id) FILTER (WHERE kh.status = 'HADIR') AS total_hadir,
  COUNT(kh.id) FILTER (WHERE kh.status = 'SAKIT') AS total_sakit,
  COUNT(kh.id) FILTER (WHERE kh.status = 'IZIN') AS total_izin,
  COUNT(kh.id) FILTER (WHERE kh.status = 'ALPA') AS total_alpa,
  ROUND(
    COUNT(kh.id) FILTER (WHERE kh.status = 'HADIR') * 100.0 / NULLIF(COUNT(kh.id), 0),
    2
  ) AS persentase_hadir
FROM kehadiran kh
JOIN siswa s ON kh.siswa_id = s.id AND s.deleted_at IS NULL
LEFT JOIN kelas k ON s.kelas_id = k.id AND k.deleted_at IS NULL
JOIN mata_pelajaran mp ON kh.mata_pelajaran_id = mp.id AND mp.deleted_at IS NULL
GROUP BY
  kh.siswa_id, s.nis, s.nama, s.kelas_id, k.nama, kh.mata_pelajaran_id, mp.kode, mp.nama;

CREATE OR REPLACE VIEW v_siswa_kehadiran_rendah AS
WITH threshold AS (
  SELECT COALESCE(
    (SELECT NULLIF(nilai, '')::NUMERIC FROM pengaturan_sistem WHERE kunci = 'ATTENDANCE_THRESHOLD'),
    75.0
  ) AS val
)
SELECT
  pk.siswa_id,
  pk.nis,
  pk.nama_siswa,
  pk.kelas_id,
  pk.nama_kelas,
  pk.mata_pelajaran_id,
  pk.kode_mapel,
  pk.nama_mapel,
  pk.total_pertemuan,
  pk.total_hadir,
  pk.total_sakit,
  pk.total_izin,
  pk.total_alpa,
  pk.persentase_hadir,
  t.val AS attendance_threshold
FROM v_persentase_kehadiran pk
CROSS JOIN threshold t
WHERE pk.persentase_hadir < t.val;

CREATE OR REPLACE VIEW v_ringkasan_prestasi AS
SELECT
  p.status_verifikasi,
  p.tingkat,
  COUNT(p.id) AS total_prestasi,
  COUNT(DISTINCT p.siswa_id) AS total_siswa
FROM prestasi p
JOIN siswa s ON p.siswa_id = s.id AND s.deleted_at IS NULL
GROUP BY
  p.status_verifikasi, p.tingkat;

-- 5.5 Grants Hak Akses untuk simpatik_app
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'simpatik_app') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO simpatik_app;
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO simpatik_app;
    ALTER DEFAULT PRIVILEGES FOR ROLE simpatik_admin IN SCHEMA public
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO simpatik_app;
    ALTER DEFAULT PRIVILEGES FOR ROLE simpatik_admin IN SCHEMA public
      GRANT USAGE, SELECT ON SEQUENCES TO simpatik_app;
    REVOKE UPDATE, DELETE ON audit_log FROM simpatik_app;
  END IF;
END
$$;
