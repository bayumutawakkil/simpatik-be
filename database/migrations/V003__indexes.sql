-- ============================================================================
-- MIGRATION: V003__indexes.sql
-- DESKRIPSI: Pembuatan index teroptimasi (B-Tree, Partial Index, dan GIN pg_trgm)
-- AUTHOR: SIMPATIK Database Engineering Team
-- ============================================================================

BEGIN;

-- 1. Index untuk tabel siswa
-- Partial index: siswa aktif per kelas (sering difilter kelasnya dan tidak soft-deleted)
CREATE INDEX IF NOT EXISTS idx_siswa_kelas_id_active
  ON siswa (kelas_id)
  WHERE deleted_at IS NULL;

-- GIN trigram index: pencarian nama siswa dengan ILIKE '%nama%'
CREATE INDEX IF NOT EXISTS idx_siswa_nama_trgm
  ON siswa USING gin (nama gin_trgm_ops);

-- B-Tree lower(nama) untuk sorting & equality case-insensitive
CREATE INDEX IF NOT EXISTS idx_siswa_lower_nama
  ON siswa (lower(nama));

-- 2. Index untuk tabel guru
-- GIN trigram index: pencarian nama guru cepat
CREATE INDEX IF NOT EXISTS idx_guru_nama_trgm
  ON guru USING gin (nama gin_trgm_ops);

-- 3. Index untuk tabel nilai
-- Composite index: query nilai siswa per mapel & periode (rekap nilai rapor siswa)
CREATE INDEX IF NOT EXISTS idx_nilai_siswa_mapel_periode
  ON nilai (siswa_id, mata_pelajaran_id, periode);

-- Composite index: rekap per mapel & periode (distribusi nilai kelas/dashboard)
CREATE INDEX IF NOT EXISTS idx_nilai_mapel_periode
  ON nilai (mata_pelajaran_id, periode);

-- 4. Index untuk tabel kehadiran
-- Index query kehadiran siswa per rentang tanggal (kehadiran individual)
CREATE INDEX IF NOT EXISTS idx_kehadiran_siswa_tanggal
  ON kehadiran (siswa_id, tanggal);

-- Index rekap kehadiran per mata pelajaran dan tanggal
CREATE INDEX IF NOT EXISTS idx_kehadiran_mapel_tanggal
  ON kehadiran (mata_pelajaran_id, tanggal);

-- 5. Index untuk tabel prestasi
-- Index per siswa
CREATE INDEX IF NOT EXISTS idx_prestasi_siswa_id
  ON prestasi (siswa_id);

-- Index per status verifikasi (filtering daftar pending verifikasi oleh admin)
CREATE INDEX IF NOT EXISTS idx_prestasi_status_verifikasi
  ON prestasi (status_verifikasi);

-- Index komposit bidang dan tingkat
CREATE INDEX IF NOT EXISTS idx_prestasi_bidang_tingkat
  ON prestasi (bidang, tingkat);

-- 6. Index untuk tabel catatan_perkembangan
-- Index riwayat perkembangan siswa diurutkan dari yang terbaru
CREATE INDEX IF NOT EXISTS idx_catatan_perkembangan_siswa_tanggal
  ON catatan_perkembangan (siswa_id, tanggal DESC);

-- 7. Index untuk tabel penugasan_guru
-- Pencarian kelas/mapel yang diampu oleh seorang guru
CREATE INDEX IF NOT EXISTS idx_penugasan_guru_guru_id
  ON penugasan_guru (guru_id);

-- Pencarian guru yang mengajar di kelas tertentu
CREATE INDEX IF NOT EXISTS idx_penugasan_guru_kelas_id
  ON penugasan_guru (kelas_id);

-- 8. Index untuk tabel audit_log
-- Index untuk penelusuran audit berdasarkan entitas yang dimodifikasi
CREATE INDEX IF NOT EXISTS idx_audit_log_entitas_entitas_id
  ON audit_log (entitas, entitas_id);

-- Index urutan kronologis audit terbaru
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at_desc
  ON audit_log (created_at DESC);

COMMIT;
