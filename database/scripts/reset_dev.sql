-- ============================================================================
-- SCRIPT: reset_dev.sql
-- DESKRIPSI: Mengosongkan semua tabel dan memuat ulang seed data dummy
-- KEAMANAN: HANYA DAPAT DIJALANKAN DI DATABASE DEVELOPMENT (simpatik_db)
-- AUTHOR: SIMPATIK Database Engineering Team
-- ============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
  -- Validasi keamanan nama database
  IF current_database() <> 'simpatik_db' THEN
    RAISE EXCEPTION 'RESET DITOLAK! Script reset_dev.sql hanya diizinkan berjalan di database simpatik_db. Database saat ini: %', current_database();
  END IF;
  RAISE NOTICE 'Memulai pembersihan database development: %', current_database();
END
$$;

BEGIN;

-- 1. Truncate semua tabel data aplikasi dengan RESTART IDENTITY CASCADE
TRUNCATE TABLE
  audit_log,
  bukti_prestasi,
  prestasi,
  catatan_perkembangan,
  kehadiran,
  nilai,
  penugasan_guru,
  siswa,
  mata_pelajaran,
  kelas,
  guru,
  users,
  pengaturan_sistem
RESTART IDENTITY CASCADE;

COMMIT;

\echo 'Semua tabel telah dikosongkan. Menjalankan ulang seed 001_dummy_data.sql...'
\i seeds/001_dummy_data.sql

\echo '---------------------------------------------------'
\echo 'Reset development database dan seeding ulang sukses!'
\echo '---------------------------------------------------'
