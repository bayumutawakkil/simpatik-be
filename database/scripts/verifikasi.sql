-- ============================================================================
-- SCRIPT: verifikasi.sql
-- DESKRIPSI: Verifikasi kelengkapan objek database, jumlah baris tabel, view, dan integritas data
-- EKSEKUSI: Dapat dijalankan via psql atau pgAdmin Query Tool
-- AUTHOR: SIMPATIK Database Engineering Team
-- ============================================================================

\set ON_ERROR_STOP on

-- ============================================================================
-- BAGIAN 1: JUMLAH BARIS TIAP TABEL
-- ============================================================================
SELECT 'RINGKASAN JUMLAH BARIS TABEL' AS status;

SELECT
  table_name,
  cnt AS total_baris
FROM (
  SELECT 'users' AS table_name, count(*) AS cnt FROM users
  UNION ALL
  SELECT 'guru', count(*) FROM guru
  UNION ALL
  SELECT 'kelas', count(*) FROM kelas
  UNION ALL
  SELECT 'mata_pelajaran', count(*) FROM mata_pelajaran
  UNION ALL
  SELECT 'penugasan_guru', count(*) FROM penugasan_guru
  UNION ALL
  SELECT 'siswa', count(*) FROM siswa
  UNION ALL
  SELECT 'nilai', count(*) FROM nilai
  UNION ALL
  SELECT 'kehadiran', count(*) FROM kehadiran
  UNION ALL
  SELECT 'prestasi', count(*) FROM prestasi
  UNION ALL
  SELECT 'bukti_prestasi', count(*) FROM bukti_prestasi
  UNION ALL
  SELECT 'catatan_perkembangan', count(*) FROM catatan_perkembangan
  UNION ALL
  SELECT 'pengaturan_sistem', count(*) FROM pengaturan_sistem
  UNION ALL
  SELECT 'audit_log', count(*) FROM audit_log
) t
ORDER BY table_name;

-- ============================================================================
-- BAGIAN 2: VERIFIKASI ATURAN SPESIFIKASI SISTEM
-- ============================================================================
SELECT 'PENGUJIAN INTEGRITAS DAN VALIDASI BISNIS' AS status;

-- 1. Jumlah Admin = 1, Guru = 5, Siswa Aktif = 58 (60 dikurangi 2 soft-deleted)
SELECT
  '1. Jumlah Akun & Siswa Aktif' AS uji,
  CASE
    WHEN (SELECT count(*) FROM users WHERE role = 'ADMIN') = 1
     AND (SELECT count(*) FROM guru WHERE deleted_at IS NULL) = 5
     AND (SELECT count(*) FROM siswa WHERE deleted_at IS NULL) = 58
     AND (SELECT count(*) FROM siswa WHERE deleted_at IS NOT NULL) = 2
    THEN 'LULUS (1 Admin, 5 Guru, 58 Siswa Aktif, 2 Soft-Deleted)'
    ELSE 'GAGAL'
  END AS hasil,
  (SELECT count(*) FROM users WHERE role = 'ADMIN') AS admin_count,
  (SELECT count(*) FROM guru WHERE deleted_at IS NULL) AS guru_count,
  (SELECT count(*) FROM siswa WHERE deleted_at IS NULL) AS siswa_aktif_count,
  (SELECT count(*) FROM siswa WHERE deleted_at IS NOT NULL) AS siswa_deleted_count;

-- 2. Tidak ada nilai di luar rentang 0 - 100
SELECT
  '2. Rentang Nilai (0 - 100)' AS uji,
  CASE
    WHEN count(*) = 0 THEN 'LULUS (Semua nilai dalam rentang valid 0 - 100)'
    ELSE 'GAGAL (Ditemukan nilai di luar 0 - 100)'
  END AS hasil,
  count(*) AS total_pelanggaran
FROM nilai
WHERE nilai < 0 OR nilai > 100;

-- 3. Tidak ada kehadiran duplikat per siswa, mapel, dan tanggal
SELECT
  '3. Keunikan Kehadiran (siswa, mapel, tgl)' AS uji,
  CASE
    WHEN count(*) = 0 THEN 'LULUS (Tidak ada duplikasi pencatatan kehadiran)'
    ELSE 'GAGAL (Ditemukan duplikasi kehadiran)'
  END AS hasil,
  count(*) AS total_duplikat
FROM (
  SELECT siswa_id, mata_pelajaran_id, tanggal, count(*)
  FROM kehadiran
  GROUP BY siswa_id, mata_pelajaran_id, tanggal
  HAVING count(*) > 1
) sub;

-- 4. Setiap siswa yang memiliki nilai berada di kelas yang memiliki penugasan untuk mapel tersebut
SELECT
  '4. Integritas Penugasan Nilai' AS uji,
  CASE
    WHEN count(*) = 0 THEN 'LULUS (Semua nilai siswa selaras dengan penugasan guru di kelasnya)'
    ELSE 'GAGAL (Ada nilai untuk mapel yang tidak diajarkan di kelas siswa)'
  END AS hasil,
  count(*) AS total_anomali
FROM nilai n
JOIN siswa s ON n.siswa_id = s.id
WHERE NOT EXISTS (
  SELECT 1 FROM penugasan_guru pg
  WHERE pg.kelas_id = s.kelas_id
    AND pg.mata_pelajaran_id = n.mata_pelajaran_id
    AND pg.guru_id = n.guru_id
);

-- 5. Tidak ada prestasi DIVERIFIKASI tanpa diverifikasi_oleh_id dan diverifikasi_at
SELECT
  '5. Integritas Verifikasi Prestasi' AS uji,
  CASE
    WHEN count(*) = 0 THEN 'LULUS (Semua prestasi DIVERIFIKASI memiliki data verifikator & timestamp valid)'
    ELSE 'GAGAL (Ditemukan prestasi diverifikasi tanpa identitas verifikator)'
  END AS hasil,
  count(*) AS total_anomali
FROM prestasi
WHERE status_verifikasi = 'DIVERIFIKASI'
  AND (diverifikasi_oleh_id IS NULL OR diverifikasi_at IS NULL);

-- ============================================================================
-- BAGIAN 3: VERIFIKASI VIEWS ANALYTICAL
-- ============================================================================
SELECT 'PENGUJIAN HASIL ANALYTICAL VIEWS' AS status;

-- Ringkasan Prestasi
SELECT * FROM v_ringkasan_prestasi ORDER BY tingkat, status_verifikasi;

-- Deteksi Siswa dengan Kehadiran Rendah (< 75%)
SELECT
  siswa_id,
  nis,
  nama_siswa,
  nama_kelas,
  kode_mapel,
  total_pertemuan,
  total_hadir,
  total_alpa,
  persentase_hadir
FROM v_siswa_kehadiran_rendah
LIMIT 10;

-- Sampel Rata-rata Nilai Siswa
SELECT
  nis,
  nama_siswa,
  kode_mapel,
  periode,
  rata_rata,
  nilai_terendah,
  nilai_tertinggi
FROM v_rata_rata_nilai_siswa
LIMIT 10;
