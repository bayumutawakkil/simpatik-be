-- ============================================================================
-- MIGRATION: V006__add_kepsek_role.sql
-- DESKRIPSI: Menambahkan role Kepala Sekolah untuk akses baca terbatas
-- ============================================================================

ALTER TYPE role_pengguna ADD VALUE IF NOT EXISTS 'KEPSEK';
