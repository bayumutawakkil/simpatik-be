-- ============================================================================
-- SCRIPT: 00_setup_role_dan_database.sql
-- DESKRIPSI: Setup awal role dan database SIMPATIK
-- EKSEKUSI: Dijalankan sebagai superuser PostgreSQL (contoh: user 'postgres')
-- ============================================================================

-- Catatan Keamanan:
-- Ganti placeholder 'GANTI_PASSWORD_ADMIN' dan 'GANTI_PASSWORD_APP'
-- dengan password yang kuat sebelum menjalankan script ini di lingkungan produksi/testing.
-- Password tidak boleh di-commit secara permanen.

\set ON_ERROR_STOP on

-- 1. Buat Role Admin (Pemilik objek database, menjalankan migrasi DDL)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'simpatik_admin') THEN
    CREATE ROLE simpatik_admin LOGIN PASSWORD 'GANTI_PASSWORD_ADMIN';
    RAISE NOTICE 'Role simpatik_admin berhasil dibuat.';
  ELSE
    RAISE NOTICE 'Role simpatik_admin sudah ada.';
  END IF;
END
$$;

-- 2. Buat Role App (Hak akses terbatas DML runtime aplikasi: SELECT, INSERT, UPDATE, DELETE)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'simpatik_app') THEN
    CREATE ROLE simpatik_app LOGIN PASSWORD 'GANTI_PASSWORD_APP';
    RAISE NOTICE 'Role simpatik_app berhasil dibuat.';
  ELSE
    RAISE NOTICE 'Role simpatik_app sudah ada.';
  END IF;
END
$$;

-- 3. Buat Database simpatik_db dengan owner simpatik_admin
SELECT 'CREATE DATABASE simpatik_db WITH OWNER = simpatik_admin ENCODING = ''UTF8'' TEMPLATE = template0'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'simpatik_db')\gexec

-- 4. Hubungkan ke database simpatik_db dan atur privilege awal schema public
\c simpatik_db

ALTER SCHEMA public OWNER TO simpatik_admin;
GRANT CONNECT ON DATABASE simpatik_db TO simpatik_app;
GRANT USAGE ON SCHEMA public TO simpatik_app;

-- Verifikasi status role dan database
\echo '---------------------------------------------------'
\echo 'Setup role dan database simpatik_db selesai!'
\echo '---------------------------------------------------'
