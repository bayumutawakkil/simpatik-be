-- ============================================================================
-- MIGRATION: V001__extensions_and_enums.sql
-- DESKRIPSI: Inisialisasi ekstensi PostgreSQL dan tipe data ENUM
-- AUTHOR: SIMPATIK Database Engineering Team
-- ============================================================================

BEGIN;

-- 1. Ekstensi
-- pgcrypto: untuk gen_random_uuid(), hashing, kriptografi
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- citext: untuk tipe data case-insensitive string (khususnya email)
CREATE EXTENSION IF NOT EXISTS citext;

-- pg_trgm: untuk pencarian substring teks cepat / partial search (GIN indexing)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. Tipe Data ENUM
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'role_pengguna') THEN
    CREATE TYPE role_pengguna AS ENUM ('ADMIN', 'GURU');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'jenis_kelamin') THEN
    CREATE TYPE jenis_kelamin AS ENUM ('LAKI_LAKI', 'PEREMPUAN');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'jenis_nilai') THEN
    CREATE TYPE jenis_nilai AS ENUM ('HARIAN', 'TUGAS', 'UTS', 'UAS');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_kehadiran') THEN
    CREATE TYPE status_kehadiran AS ENUM ('HADIR', 'SAKIT', 'IZIN', 'ALPA');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tingkat_prestasi') THEN
    CREATE TYPE tingkat_prestasi AS ENUM (
      'SEKOLAH',
      'KECAMATAN',
      'KABUPATEN',
      'PROVINSI',
      'NASIONAL',
      'INTERNASIONAL'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_verifikasi') THEN
    CREATE TYPE status_verifikasi AS ENUM ('PENDING', 'DIVERIFIKASI', 'DITOLAK');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'aspek_perkembangan') THEN
    CREATE TYPE aspek_perkembangan AS ENUM (
      'AKADEMIK',
      'SOSIAL',
      'EMOSIONAL',
      'KARAKTER',
      'KETERAMPILAN'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_perkembangan_siswa') THEN
    CREATE TYPE status_perkembangan_siswa AS ENUM ('BAIK', 'PERHATIAN', 'KRITIS');
  END IF;
END
$$;

COMMIT;
