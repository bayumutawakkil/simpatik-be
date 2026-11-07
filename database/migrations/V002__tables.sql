-- ============================================================================
-- MIGRATION: V002__tables.sql
-- DESKRIPSI: Pembuatan 13 tabel inti SIMPATIK dengan UUID, Relasi, dan Constraint
-- AUTHOR: SIMPATIK Database Engineering Team
-- ============================================================================

BEGIN;

-- 1. Tabel users
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  email CITEXT NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role role_pengguna NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Tabel guru
CREATE TABLE IF NOT EXISTS guru (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE REFERENCES users(id) ON DELETE RESTRICT,
  nip VARCHAR(30) NOT NULL UNIQUE,
  nama VARCHAR(100) NOT NULL,
  alamat TEXT,
  no_telepon VARCHAR(20),
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Tabel kelas
CREATE TABLE IF NOT EXISTS kelas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama VARCHAR(50) NOT NULL,
  tingkat SMALLINT NOT NULL CHECK (tingkat >= 1 AND tingkat <= 12),
  tahun_ajaran VARCHAR(9) NOT NULL CHECK (tahun_ajaran ~ '^\d{4}/\d{4}$'),
  wali_kelas_id UUID REFERENCES guru(id) ON DELETE SET NULL,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_kelas_nama_tahun_ajaran UNIQUE (nama, tahun_ajaran)
);

-- 4. Tabel siswa
CREATE TABLE IF NOT EXISTS siswa (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nis VARCHAR(20) NOT NULL UNIQUE,
  nama VARCHAR(100) NOT NULL,
  jenis_kelamin jenis_kelamin NOT NULL,
  tanggal_lahir DATE NOT NULL CHECK (tanggal_lahir <= CURRENT_DATE),
  alamat TEXT,
  nama_orang_tua VARCHAR(100),
  no_telepon VARCHAR(20),
  kelas_id UUID REFERENCES kelas(id) ON DELETE SET NULL,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Tabel mata_pelajaran
CREATE TABLE IF NOT EXISTS mata_pelajaran (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kode VARCHAR(10) NOT NULL UNIQUE,
  nama VARCHAR(100) NOT NULL,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Tabel penugasan_guru (relasi guru-kelas-mata pelajaran)
CREATE TABLE IF NOT EXISTS penugasan_guru (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guru_id UUID NOT NULL REFERENCES guru(id) ON DELETE CASCADE,
  kelas_id UUID REFERENCES kelas(id) ON DELETE CASCADE,
  mata_pelajaran_id UUID NOT NULL REFERENCES mata_pelajaran(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_penugasan_guru_kelas_mapel UNIQUE (guru_id, kelas_id, mata_pelajaran_id)
);

-- 7. Tabel nilai
CREATE TABLE IF NOT EXISTS nilai (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  siswa_id UUID NOT NULL REFERENCES siswa(id) ON DELETE CASCADE,
  mata_pelajaran_id UUID NOT NULL REFERENCES mata_pelajaran(id) ON DELETE RESTRICT,
  guru_id UUID NOT NULL REFERENCES guru(id) ON DELETE RESTRICT,
  periode VARCHAR(20) NOT NULL, -- Contoh: '2026-GANJIL', '2026-GENAP'
  jenis jenis_nilai NOT NULL,
  pertemuan SMALLINT DEFAULT 1 CHECK (pertemuan >= 1),
  nilai NUMERIC(5,2) NOT NULL CHECK (nilai >= 0 AND nilai <= 100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_nilai_siswa_mapel_periode_jenis_pertemuan UNIQUE (siswa_id, mata_pelajaran_id, periode, jenis, pertemuan)
);

-- 8. Tabel kehadiran
CREATE TABLE IF NOT EXISTS kehadiran (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  siswa_id UUID NOT NULL REFERENCES siswa(id) ON DELETE CASCADE,
  mata_pelajaran_id UUID NOT NULL REFERENCES mata_pelajaran(id) ON DELETE RESTRICT,
  guru_id UUID NOT NULL REFERENCES guru(id) ON DELETE RESTRICT,
  tanggal DATE NOT NULL,
  status status_kehadiran NOT NULL,
  keterangan TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_kehadiran_siswa_mapel_tanggal UNIQUE (siswa_id, mata_pelajaran_id, tanggal)
);

-- 9. Tabel prestasi
CREATE TABLE IF NOT EXISTS prestasi (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  siswa_id UUID NOT NULL REFERENCES siswa(id) ON DELETE CASCADE,
  judul VARCHAR(200) NOT NULL,
  bidang VARCHAR(50) NOT NULL, -- contoh: SAINS, OLAHRAGA, SENI, ROBOTIKA
  tingkat tingkat_prestasi NOT NULL,
  peringkat VARCHAR(50), -- Juara 1, Medali Emas, Finalis, dsb.
  tanggal_perolehan DATE NOT NULL,
  penyelenggara VARCHAR(150),
  status_verifikasi status_verifikasi NOT NULL DEFAULT 'PENDING',
  catatan_verifikasi TEXT,
  dicatat_oleh_id UUID NOT NULL REFERENCES guru(id) ON DELETE RESTRICT,
  diverifikasi_oleh_id UUID REFERENCES users(id) ON DELETE SET NULL,
  diverifikasi_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_prestasi_verifikasi CHECK (
    (status_verifikasi = 'DIVERIFIKASI' AND diverifikasi_oleh_id IS NOT NULL AND diverifikasi_at IS NOT NULL)
    OR
    (status_verifikasi <> 'DIVERIFIKASI')
  )
);

-- 10. Tabel bukti_prestasi
CREATE TABLE IF NOT EXISTS bukti_prestasi (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prestasi_id UUID NOT NULL REFERENCES prestasi(id) ON DELETE CASCADE,
  nama_file_asli VARCHAR(255) NOT NULL,
  nama_file_simpan VARCHAR(255) NOT NULL UNIQUE,
  mime_type VARCHAR(100) NOT NULL CHECK (mime_type IN ('application/pdf', 'image/jpeg', 'image/png')),
  ukuran_byte INTEGER NOT NULL CHECK (ukuran_byte > 0 AND ukuran_byte <= 5242880), -- Maksimal 5 MB
  storage_path TEXT NOT NULL,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 11. Tabel catatan_perkembangan
CREATE TABLE IF NOT EXISTS catatan_perkembangan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  siswa_id UUID NOT NULL REFERENCES siswa(id) ON DELETE CASCADE,
  guru_id UUID NOT NULL REFERENCES guru(id) ON DELETE RESTRICT,
  aspek aspek_perkembangan NOT NULL,
  isi TEXT NOT NULL,
  tanggal DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 12. Tabel pengaturan_sistem
CREATE TABLE IF NOT EXISTS pengaturan_sistem (
  kunci VARCHAR(50) PRIMARY KEY,
  nilai VARCHAR(255) NOT NULL,
  keterangan TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 13. Tabel audit_log
CREATE TABLE IF NOT EXISTS audit_log (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  aksi VARCHAR(20) NOT NULL CHECK (aksi IN ('CREATE', 'UPDATE', 'DELETE', 'LOGIN')),
  entitas VARCHAR(50) NOT NULL,
  entitas_id UUID,
  data_sebelum JSONB,
  data_sesudah JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMIT;
