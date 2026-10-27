-- ============================================================================
-- MIGRATION: V005__grants.sql
-- DESKRIPSI: Konfigurasi hak akses aman untuk role runtime simpatik_app
-- AUTHOR: SIMPATIK Database Engineering Team
-- ============================================================================

BEGIN;

-- Berikan izin akses DML ke tabel yang sudah ada pada schema public
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO simpatik_app;

-- Berikan hak akses sequence (untuk tabel yang menggunakan SERIAL / BIGSERIAL seperti audit_log)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO simpatik_app;

-- Konfigurasikan DEFAULT PRIVILEGES agar tabel baru yang dibuat di masa depan otomatis memiliki hak DML untuk simpatik_app
ALTER DEFAULT PRIVILEGES FOR ROLE simpatik_admin IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO simpatik_app;

ALTER DEFAULT PRIVILEGES FOR ROLE simpatik_admin IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO simpatik_app;

-- PENTING: Cabut hak UPDATE dan DELETE pada tabel audit_log dari simpatik_app
-- Audit log bersifat Append-Only / Immutable bagi user aplikasi untuk menjamin integritas forensik data
REVOKE UPDATE, DELETE ON audit_log FROM simpatik_app;

COMMIT;
